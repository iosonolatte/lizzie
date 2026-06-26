package main

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"sync"
	"sync/atomic"
	"time"
)

// katago wraps a single KataGo subprocess. It exposes io.ReadWriter so
// the server can bridge it to a TCP client with io.Copy.
//
// The subprocess is started lazily on first use and shut down when
// the parent context is cancelled or Stop() is called. A second
// concurrent client will reuse the same process.
type katago struct {
	binary string
	config string
	model  string

	mu      sync.Mutex
	cmd     *exec.Cmd
	stdin   io.WriteCloser
	stdout  io.ReadCloser
	stderr  io.ReadCloser
	scanner *bufio.Scanner // for stderr line-by-line logging

	idleTimeout time.Duration
	shutdownTO  time.Duration

	// last-used timestamp; read on every bridge call, written when a
	// client disconnects. Used to shut down after max-idle.
	lastUsed atomic.Int64

	// onDisconnect is called when the subprocess exits (e.g. it died,
	// or it was shut down by Stop). The server uses this to close any
	// active client connections.
	onDisconnect func()

	stopOnce sync.Once
	done     chan struct{} // closed when subprocess exits
}

func newKatago(binary, config, model string, idleTimeout, shutdownTO time.Duration, onDisconnect func()) *katago {
	return &katago{
		binary:       binary,
		config:       config,
		model:        model,
		idleTimeout:  idleTimeout,
		shutdownTO:   shutdownTO,
		onDisconnect: onDisconnect,
		done:         make(chan struct{}),
	}
}

// Start launches the KataGo subprocess if it is not already running.
// It is safe to call concurrently; only the first call has effect.
func (k *katago) Start(ctx context.Context) error {
	k.mu.Lock()
	defer k.mu.Unlock()

	if k.cmd != nil && k.cmd.Process != nil {
		// Already running; bump the last-used timestamp and return.
		k.lastUsed.Store(time.Now().Unix())
		return nil
	}

	args := []string{}
	if k.model != "" {
		// Only pass --model when the user gave us one. Passing an
		// empty --model trips some KataGo builds (and is meaningless
		// anyway; the config file can supply the model).
		args = append(args, "--model", k.model)
	}
	args = append(args, "--config", k.config)
	log.Printf("katago: starting %s %v", k.binary, args)

	cmd := exec.CommandContext(ctx, k.binary, args...)
	cmd.Env = append(os.Environ(), "OMP_NUM_THREADS=2") // sane default for a phone-class host

	stdin, err := cmd.StdinPipe()
	if err != nil {
		return fmt.Errorf("stdin pipe: %w", err)
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		stdin.Close()
		return fmt.Errorf("stdout pipe: %w", err)
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		stdin.Close()
		stdout.Close()
		return fmt.Errorf("stderr pipe: %w", err)
	}

	if err := cmd.Start(); err != nil {
		stdin.Close()
		stdout.Close()
		stderr.Close()
		return fmt.Errorf("start %s: %w", k.binary, err)
	}

	k.cmd = cmd
	k.stdin = stdin
	k.stdout = stdout
	k.stderr = stderr
	k.scanner = bufio.NewScanner(stderr)
	k.scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	k.lastUsed.Store(time.Now().Unix())

	// Re-create the done channel in case this is a re-start after a
	// previous subprocess exited.
	k.done = make(chan struct{})

	go k.pumpStderr()
	go k.wait()

	log.Printf("katago: started (pid %d)", cmd.Process.Pid)
	return nil
}

// Read proxies to KataGo's stdout. The contract matches io.Reader.
func (k *katago) Read(p []byte) (int, error) {
	k.mu.Lock()
	stdout := k.stdout
	k.mu.Unlock()
	if stdout == nil {
		return 0, io.EOF
	}
	return stdout.Read(p)
}

// Write proxies to KataGo's stdin. The contract matches io.Writer.
func (k *katago) Write(p []byte) (int, error) {
	k.mu.Lock()
	stdin := k.stdin
	k.mu.Unlock()
	if stdin == nil {
		return 0, io.ErrClosedPipe
	}
	return stdin.Write(p)
}

// Touch updates the last-used timestamp. Called when a client connects
// or finishes bridging.
func (k *katago) Touch() {
	k.lastUsed.Store(time.Now().Unix())
}

// Stop gracefully terminates the subprocess. Sends SIGINT, waits up
// to shutdownTO, then SIGKILLs if still alive. Idempotent.
func (k *katago) Stop() {
	k.stopOnce.Do(func() {
		k.stop()
	})
}

func (k *katago) stop() {
	k.mu.Lock()
	cmd := k.cmd
	stdin := k.stdin
	k.cmd = nil
	k.stdin = nil
	k.stdout = nil
	k.stderr = nil
	k.scanner = nil
	k.mu.Unlock()

	if cmd == nil || cmd.Process == nil {
		return
	}

	log.Printf("katago: stopping (pid %d)", cmd.Process.Pid)

	// Try a graceful quit via GTP first.
	if stdin != nil {
		_, _ = stdin.Write([]byte("9 quit\n"))
		_ = stdin.Close()
	}

	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()

	select {
	case err := <-done:
		log.Printf("katago: exited (%v)", err)
	case <-time.After(k.shutdownTO):
		log.Printf("katago: graceful shutdown timed out after %s, sending SIGKILL", k.shutdownTO)
		_ = cmd.Process.Kill()
		<-done
	}

	if k.onDisconnect != nil {
		k.onDisconnect()
	}
}

// IsRunning reports whether the subprocess is currently up.
func (k *katago) IsRunning() bool {
	k.mu.Lock()
	defer k.mu.Unlock()
	return k.cmd != nil && k.cmd.ProcessState == nil
}

// IdleMonitor shuts down the subprocess if no client has touched it
// for maxIdle. It exits when ctx is cancelled. Safe to call once.
func (k *katago) IdleMonitor(ctx context.Context) {
	if k.idleTimeout <= 0 {
		return
	}
	t := time.NewTicker(30 * time.Second)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			last := time.Unix(k.lastUsed.Load(), 0)
			if k.IsRunning() && time.Since(last) > k.idleTimeout {
				log.Printf("katago: idle for %s, shutting down", time.Since(last).Truncate(time.Second))
				k.Stop()
				return
			}
		}
	}
}

// pumpStderr logs KataGo's stderr line-by-line.
func (k *katago) pumpStderr() {
	for {
		k.mu.Lock()
		scanner := k.scanner
		k.mu.Unlock()
		if scanner == nil {
			return
		}
		for scanner.Scan() {
			log.Printf("katago: %s", scanner.Text())
		}
		// If the scanner stopped, the stderr pipe is closed (subprocess
		// exited). Bail out; wait() will log the exit status.
		return
	}
}

// wait blocks until the subprocess exits, then logs the result and
// closes stdin/stdout pipes so any active client gets an EOF.
func (k *katago) wait() {
	k.mu.Lock()
	cmd := k.cmd
	k.mu.Unlock()
	if cmd == nil {
		return
	}
	err := cmd.Wait()
	exitCode := -1
	if cmd.ProcessState != nil {
		exitCode = cmd.ProcessState.ExitCode()
	}
	if err != nil {
		var exitErr *exec.ExitError
		switch {
		case errors.As(err, &exitErr):
			log.Printf("katago: exited with code %d", exitCode)
		default:
			log.Printf("katago: exited with error: %v", err)
		}
	} else {
		log.Printf("katago: exited cleanly (code %d)", exitCode)
	}
	close(k.done)
	if k.onDisconnect != nil {
		k.onDisconnect()
	}
}

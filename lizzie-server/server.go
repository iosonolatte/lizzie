package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"sync"
	"sync/atomic"
	"time"
)

// server is a single-listener TCP proxy. At most one client is active
// at a time; a new connection kicks the previous one.
type server struct {
	cfg *config

	ka *katago

	mu      sync.Mutex
	current net.Conn // the active client, or nil

	closing atomic.Bool
}

func newServer(cfg *config) *server {
	s := &server{cfg: cfg}
	s.ka = newKatago(
		cfg.katago, cfg.gtpConfig, cfg.model,
		cfg.maxIdle, cfg.shutdownTO,
		// onDisconnect: when the subprocess dies, close the current client
		// so the mobile app sees a disconnect and can surface an error.
		func() {
			s.mu.Lock()
			c := s.current
			s.current = nil
			s.mu.Unlock()
			if c != nil {
				_ = c.Close()
			}
		},
	)
	return s
}

// Run listens on cfg.addr and serves until ctx is cancelled.
func (s *server) Run(ctx context.Context) error {
	ln, err := net.Listen("tcp", s.cfg.addr)
	if err != nil {
		return fmt.Errorf("listen %s: %w", s.cfg.addr, err)
	}
	defer ln.Close()
	log.Printf("server: listening on %s", ln.Addr())

	// Idle monitor: shuts down katago after maxIdle of disuse.
	go s.ka.IdleMonitor(ctx)

	// On shutdown, stop the subprocess.
	go func() {
		<-ctx.Done()
		log.Printf("server: shutdown signal received")
		s.closing.Store(true)
		_ = ln.Close()
		s.ka.Stop()
		// Close any active client so its io.Copy unblocks.
		s.mu.Lock()
		c := s.current
		s.current = nil
		s.mu.Unlock()
		if c != nil {
			_ = c.Close()
		}
	}()

	for {
		conn, err := ln.Accept()
		if err != nil {
			if s.closing.Load() || errors.Is(err, net.ErrClosed) {
				return nil
			}
			return fmt.Errorf("accept: %w", err)
		}
		go s.serve(conn)
	}
}

// serve handles a single client connection. It is the hot path: ensure
// katago is up, register as the active client (kicking the previous
// one if any), bridge bytes in both directions until either side
// closes.
func (s *server) serve(conn net.Conn) {
	remote := conn.RemoteAddr().String()
	log.Printf("server: client connected from %s", remote)

	s.mu.Lock()
	prev := s.current
	s.current = conn
	s.mu.Unlock()

	// Kick the previous client, if any.
	if prev != nil {
		log.Printf("server: kicking previous client %s for new connection", prev.RemoteAddr())
		_ = prev.Close()
	}

	// Ensure the KataGo subprocess is up. If start fails, return the
	// error to the client and disconnect.
	if err := s.ka.Start(context.Background()); err != nil {
		log.Printf("server: failed to start katago for %s: %v", remote, err)
		_, _ = io.WriteString(conn, "? cannot start katago: "+err.Error()+"\n")
		s.clearCurrent(conn)
		_ = conn.Close()
		return
	}
	s.ka.Touch()

	defer func() {
		_ = conn.Close()
		s.clearCurrent(conn)
		s.ka.Touch()
		log.Printf("server: client %s disconnected", remote)
	}()

	// Bridge client <-> katago. Whichever direction closes first ends
	// the session.
	errCh := make(chan error, 2)
	go func() {
		_, err := s.bridge(conn, s.ka, "client->katago")
		errCh <- err
	}()
	go func() {
		_, err := s.bridge(s.ka, conn, "katago->client")
		errCh <- err
	}()

	// Return after the first direction closes, or the subprocess dies.
	select {
	case err := <-errCh:
		if err != nil && !isClosed(err) {
			log.Printf("server: bridge error for %s: %v", remote, err)
		}
	case <-s.ka.done:
		log.Printf("server: katago exited while serving %s", remote)
	}
}

// bridge copies bytes from src to dst, logging the byte count when
// verbose mode is on. The src must also satisfy io.Writer to support
// the reverse direction (we reuse katago for both).
func (s *server) bridge(dst io.Writer, src io.Reader, label string) (int64, error) {
	n, err := io.Copy(dst, src)
	if s.cfg.logVerbose {
		log.Printf("server: %s transferred %d bytes", label, n)
	}
	return n, err
}

// clearCurrent unregisters conn as the active client if it is still
// the current one. Safe under concurrent serves.
func (s *server) clearCurrent(conn net.Conn) {
	s.mu.Lock()
	if s.current == conn {
		s.current = nil
	}
	s.mu.Unlock()
}

// isClosed returns true if err represents a normal "connection closed"
// condition that should not be logged as an error.
func isClosed(err error) bool {
	if err == nil {
		return true
	}
	if errors.Is(err, io.EOF) || errors.Is(err, io.ErrClosedPipe) {
		return true
	}
	var netErr *net.OpError
	if errors.As(err, &netErr) {
		return true
	}
	// Common Windows / Linux messages for "use of closed connection"
	// or "broken pipe" -- match on the error string as a last resort.
	msg := err.Error()
	for _, s := range []string{"closed", "broken pipe", "forcibly closed"} {
		if containsFold(msg, s) {
			return true
		}
	}
	return false
}

// containsFold is a tiny case-insensitive substring check (avoid
// pulling in strings just for one helper).
func containsFold(s, substr string) bool {
	if len(substr) == 0 {
		return true
	}
	if len(substr) > len(s) {
		return false
	}
	for i := 0; i+len(substr) <= len(s); i++ {
		match := true
		for j := 0; j < len(substr); j++ {
			a, b := s[i+j], substr[j]
			if a >= 'A' && a <= 'Z' {
				a += 'a' - 'A'
			}
			if b >= 'A' && b <= 'Z' {
				b += 'a' - 'A'
			}
			if a != b {
				match = false
				break
			}
		}
		if match {
			return true
		}
	}
	return false
}

// ping is a tiny utility kept here for future use; builds a noop
// connection test. Not used in production paths.
var _ = time.Second

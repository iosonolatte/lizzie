// Command lizzie-server is a tiny single-user TCP proxy that bridges the
// Lizzie Mobile Flutter app to a local KataGo subprocess.
//
// It listens for GTP-over-TCP connections from the mobile client, spawns
// a KataGo subprocess on first use, and bidirectionally forwards bytes
// between the client and KataGo's stdin/stdout. A second client
// connection kicks the first.
//
// Example:
//
//	lizzie-server \
//	    --addr :7878 \
//	    --katago ./katago \
//	    --config ./gtp.cfg \
//	    --model ./kata1-b18c384nbt.bin.gz
//
// See README.md for the full list of flags.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	cfg, err := parseFlags(os.Args[1:])
	if err != nil {
		fmt.Fprintf(os.Stderr, "lizzie-server: %v\n", err)
		os.Exit(2)
	}

	if err := run(cfg); err != nil {
		log.Fatalf("lizzie-server: %v", err)
	}
}

// config is the parsed CLI configuration.
type config struct {
	addr       string        // listen address, e.g. ":7878" or "127.0.0.1:7878"
	katago     string        // path to katago binary (required)
	gtpConfig  string        // path to gtp config file (required)
	model      string        // path to neural-net model (required)
	logVerbose bool          // enable verbose per-frame logging
	maxIdle    time.Duration // shut down katago after this much idle time (0 = never)
	shutdownTO time.Duration // maximum time to wait for katago to exit on shutdown
}

func parseFlags(args []string) (*config, error) {
	fs := flag.NewFlagSet("lizzie-server", flag.ContinueOnError)

	addr := fs.String("addr", ":7878", "listen address (host:port)")
	katago := fs.String("katago", "katago", "path to katago binary (or name on PATH)")
	gtp := fs.String("config", "gtp.cfg", "path to KataGo GTP config file")
	model := fs.String("model", "", "path to KataGo neural-net model (.bin.gz); empty = pass --model '' and let config file decide")
	verbose := fs.Bool("verbose", false, "log every byte forwarded (very chatty)")
	maxIdle := fs.Duration("max-idle", 0, "shut down the katago subprocess after this much idle time (0 = keep alive forever)")
	shutdownTO := fs.Duration("shutdown-timeout", 5*time.Second, "max time to wait for katago to exit on server shutdown")

	if err := fs.Parse(args); err != nil {
		return nil, err
	}

	if *gtp == "" {
		return nil, errors.New("--config is required (path to gtp.cfg)")
	}
	if _, err := os.Stat(*gtp); err != nil {
		return nil, fmt.Errorf("--config %q: %w", *gtp, err)
	}

	return &config{
		addr:       *addr,
		katago:     *katago,
		gtpConfig:  *gtp,
		model:      *model,
		logVerbose: *verbose,
		maxIdle:    *maxIdle,
		shutdownTO: *shutdownTO,
	}, nil
}

// run is the main entry after flag parsing. It sets up a context that
// cancels on SIGINT/SIGTERM, starts the TCP server, and blocks until
// the server exits.
func run(cfg *config) error {
	log.SetFlags(log.LstdFlags | log.Lmicroseconds)
	log.Printf("lizzie-server starting: addr=%s katago=%s config=%s model=%q",
		cfg.addr, cfg.katago, cfg.gtpConfig, cfg.model)

	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer cancel()

	srv := newServer(cfg)
	if err := srv.Run(ctx); err != nil && !errors.Is(err, context.Canceled) {
		return err
	}
	log.Printf("lizzie-server stopped")
	return nil
}

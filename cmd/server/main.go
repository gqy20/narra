// Command server exposes the player application to a local Godot client.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"fantu/internal/scenario"
	gameserver "fantu/internal/server"
)

func main() {
	address := flag.String("addr", "127.0.0.1:8787", "loopback listen address")
	dataDir := flag.String("data", filepath.FromSlash("data/blackwind"), "scenario data directory")
	saveDir := flag.String("saves", filepath.FromSlash("saves"), "save slot directory")
	flag.Parse()

	bundle, err := scenario.Load(*dataDir)
	if err != nil {
		fail(err)
	}
	service := &http.Server{
		Addr:              *address,
		Handler:           gameserver.New(bundle, *saveDir).Handler(),
		ReadHeaderTimeout: 5 * time.Second,
	}

	stopped := make(chan os.Signal, 1)
	signal.Notify(stopped, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-stopped
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = service.Shutdown(ctx)
	}()

	fmt.Printf("fantu server listening on http://%s\n", *address)
	if err := service.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		fail(err)
	}
}

func fail(err error) {
	fmt.Fprintln(os.Stderr, "server:", err)
	os.Exit(1)
}

// Command server exposes the player application to a local Godot client.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	"fantu/internal/logfile"
	"fantu/internal/scenario"
	gameserver "fantu/internal/server"
)

func main() {
	address := flag.String("addr", "127.0.0.1:8787", "loopback listen address")
	dataDir := flag.String("data", filepath.FromSlash("data/blackwind"), "scenario data directory")
	saveDir := flag.String("saves", filepath.FromSlash("saves"), "save slot directory")
	logPath := flag.String("log", "", "server log file; empty writes only to stderr")
	crashDir := flag.String("crash-dir", "", "directory for recovered HTTP panic diagnostics")
	logMaxMB := flag.Int64("log-max-mb", 5, "maximum active server log size in MiB")
	logBackups := flag.Int("log-backups", 5, "number of archived server logs to retain")
	version := flag.String("version", "dev", "game build version included in diagnostics")
	sessionID := flag.String("session-id", "", "client session identifier included in diagnostics")
	shutdownToken := flag.String("shutdown-token", "", "token required by the loopback graceful-shutdown endpoint")
	flag.Parse()
	if *sessionID == "" {
		*sessionID = fmt.Sprintf("server-%d", os.Getpid())
	}

	logOutput := io.Writer(os.Stderr)
	var rotatingLog *logfile.RotatingWriter
	if *logPath != "" {
		var err error
		rotatingLog, err = logfile.NewRotatingWriter(*logPath, *logMaxMB*1024*1024, *logBackups)
		if err != nil {
			fmt.Fprintln(os.Stderr, "server: configure logging:", err)
			os.Exit(1)
		}
		defer rotatingLog.Close()
		logOutput = io.MultiWriter(os.Stderr, rotatingLog)
	}
	logger := log.New(logOutput, "", 0)
	logEvent(logger, *sessionID, *version, "INFO", "startup", "starting rules service",
		"pid", os.Getpid(), "address", *address, "data", *dataDir, "saves", *saveDir)

	if err := os.MkdirAll(*saveDir, 0o755); err != nil {
		failWithContext(logger, *sessionID, *version, fmt.Errorf("prepare save directory: %w", err))
	}
	bundle, err := scenario.Load(*dataDir)
	if err != nil {
		failWithContext(logger, *sessionID, *version, fmt.Errorf("load scenario data: %w", err))
	}
	logEvent(logger, *sessionID, *version, "INFO", "scenario_loaded", "scenario data loaded")
	shutdownReasons := make(chan string, 1)
	requestShutdown := func(reason string) {
		select {
		case shutdownReasons <- reason:
		default:
		}
	}
	handler := gameserver.NewWithOptions(bundle, *saveDir, gameserver.Options{
		ShutdownToken: *shutdownToken,
		Shutdown: func() {
			requestShutdown("client_request")
		},
	}).Handler()
	service := &http.Server{
		Addr:              *address,
		Handler:           accessLog(handler, logger, *sessionID, *version),
		ReadHeaderTimeout: 5 * time.Second,
		ErrorLog: log.New(serverErrorWriter{
			logger:   logger,
			session:  *sessionID,
			version:  *version,
			crashDir: *crashDir,
		}, "", 0),
	}

	stopped := make(chan os.Signal, 1)
	signal.Notify(stopped, os.Interrupt, syscall.SIGTERM)
	go func() {
		signalValue := <-stopped
		requestShutdown("signal:" + signalValue.String())
	}()
	go func() {
		reason := <-shutdownReasons
		logEvent(logger, *sessionID, *version, "INFO", "shutdown_requested", "graceful shutdown requested", "reason", reason)
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := service.Shutdown(ctx); err != nil {
			logEvent(logger, *sessionID, *version, "ERROR", "shutdown_failed", "graceful shutdown failed", "error", err)
		}
	}()

	listener, err := net.Listen("tcp", *address)
	if err != nil {
		failWithContext(logger, *sessionID, *version, fmt.Errorf("listen: %w", err))
	}
	logEvent(logger, *sessionID, *version, "INFO", "listening", "rules service is ready", "url", "http://"+listener.Addr().String())
	if err := service.Serve(listener); err != nil && !errors.Is(err, http.ErrServerClosed) {
		failWithContext(logger, *sessionID, *version, fmt.Errorf("serve: %w", err))
	}
	logEvent(logger, *sessionID, *version, "INFO", "stopped", "rules service stopped")
}

func failWithContext(logger *log.Logger, sessionID, version string, err error) {
	logEvent(logger, sessionID, version, "ERROR", "fatal", "rules service cannot continue", "error", err)
	os.Exit(1)
}

func logEvent(logger *log.Logger, sessionID, version, level, event, message string, fields ...any) {
	var line strings.Builder
	line.WriteString("timestamp=")
	line.WriteString(time.Now().UTC().Format(time.RFC3339Nano))
	line.WriteString(" level=")
	line.WriteString(level)
	line.WriteString(" component=server event=")
	line.WriteString(event)
	line.WriteString(" session=")
	line.WriteString(strconv.Quote(sessionID))
	line.WriteString(" version=")
	line.WriteString(strconv.Quote(version))
	line.WriteString(" message=")
	line.WriteString(strconv.Quote(message))
	for index := 0; index+1 < len(fields); index += 2 {
		line.WriteByte(' ')
		line.WriteString(fmt.Sprint(fields[index]))
		line.WriteByte('=')
		line.WriteString(strconv.Quote(fmt.Sprint(fields[index+1])))
	}
	logger.Print(line.String())
}

type responseStatusWriter struct {
	http.ResponseWriter
	status int
}

func (writer *responseStatusWriter) WriteHeader(status int) {
	if writer.status != 0 {
		return
	}
	writer.status = status
	writer.ResponseWriter.WriteHeader(status)
}

func accessLog(next http.Handler, logger *log.Logger, sessionID, version string) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		started := time.Now()
		statusWriter := &responseStatusWriter{ResponseWriter: writer}
		next.ServeHTTP(statusWriter, request)
		status := statusWriter.status
		if status == 0 {
			status = http.StatusOK
		}
		logEvent(logger, sessionID, version, "INFO", "http_request", "request completed",
			"method", request.Method,
			"path", request.URL.Path,
			"status", status,
			"duration_ms", time.Since(started).Milliseconds(),
		)
	})
}

type serverErrorWriter struct {
	logger   *log.Logger
	session  string
	version  string
	crashDir string
}

func (writer serverErrorWriter) Write(data []byte) (int, error) {
	message := strings.TrimSpace(string(data))
	logEvent(writer.logger, writer.session, writer.version, "ERROR", "http_internal", message)
	if writer.crashDir != "" && strings.Contains(strings.ToLower(message), "panic") {
		if err := os.MkdirAll(writer.crashDir, 0o755); err == nil {
			name := "server-http-panic-" + time.Now().UTC().Format("20060102-150405.000000000") + ".log"
			_ = os.WriteFile(filepath.Join(writer.crashDir, name), data, 0o644)
		}
	}
	return len(data), nil
}

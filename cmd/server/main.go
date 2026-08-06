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
	"runtime/debug"
	"strings"
	"syscall"
	"time"

	"narra/internal/ai"
	"narra/internal/aiconfig"
	"narra/internal/crashreport"
	"narra/internal/diagnosticlog"
	"narra/internal/logfile"
	"narra/internal/scenario"
	gameserver "narra/internal/server"
)

func main() {
	if err := aiconfig.LoadDotEnv(".env"); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	aiConfig := registerAIFlags()
	address := flag.String("addr", "127.0.0.1:8787", "loopback listen address")
	dataDir := flag.String("data", filepath.FromSlash("data/blackwind"), "scenario data directory")
	saveDir := flag.String("saves", filepath.FromSlash("saves"), "save slot directory")
	logPath := flag.String("log", "", "server log file; empty writes only to stderr")
	crashDir := flag.String("crash-dir", "", "directory for recovered HTTP panic diagnostics")
	logMaxMB := flag.Int64("log-max-mb", 5, "maximum active server log size in MiB")
	logBackups := flag.Int("log-backups", 5, "number of archived server logs to retain")
	logLevelName := flag.String("log-level", "INFO", "minimum diagnostic level: DEBUG, INFO, WARN, or ERROR")
	version := flag.String("version", "dev", "game build version included in diagnostics")
	sessionID := flag.String("session-id", "", "client session identifier included in diagnostics")
	shutdownToken := flag.String("shutdown-token", "", "token required by the loopback graceful-shutdown endpoint")
	flag.Parse()
	if *sessionID == "" {
		*sessionID = fmt.Sprintf("server-%d", os.Getpid())
	}
	logLevel, err := diagnosticlog.ParseLevel(*logLevelName)
	if err != nil {
		fmt.Fprintln(os.Stderr, "server: configure logging:", err)
		os.Exit(2)
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
		logOutput = &logfile.FallbackWriter{Primary: rotatingLog, Fallback: os.Stderr}
	}
	logger := diagnosticlog.New(log.New(logOutput, "", 0), logLevel, "server", *sessionID, *version)
	defer captureUnhandledPanic(logger, *crashDir, *sessionID, *version)
	logger.Event(diagnosticlog.Info, "startup", "starting rules service",
		"pid", os.Getpid(), "address", *address, "data", *dataDir, "saves", *saveDir)

	if err := os.MkdirAll(*saveDir, 0o755); err != nil {
		failWithContext(logger, fmt.Errorf("prepare save directory: %w", err))
	}
	bundle, err := scenario.Load(*dataDir)
	if err != nil {
		failWithContext(logger, fmt.Errorf("load scenario data: %w", err))
	}
	logger.Event(diagnosticlog.Info, "scenario_loaded", "scenario data loaded")
	dialogueService, dialogueMode, err := buildDialogueService(aiConfig)
	if err != nil {
		failWithContext(logger, err)
	}
	logger.Event(diagnosticlog.Info, "ai_configured", "optional NPC dialogue configured", "mode", dialogueMode)
	shutdownReasons := make(chan string, 1)
	requestShutdown := func(reason string) {
		select {
		case shutdownReasons <- reason:
		default:
		}
	}
	handler := gameserver.NewWithOptions(bundle, *saveDir, gameserver.Options{
		ShutdownToken: *shutdownToken,
		Dialogue:      dialogueService,
		DialogueMode:  dialogueMode,
		ConfigureAI: func(settings gameserver.AISettings) (*ai.Service, string, error) {
			return buildRuntimeDialogueService(aiConfig, settings)
		},
		ReportError: func(operation string, err error) {
			logger.Event(diagnosticlog.Error, operation+"_failed", "request failed", "error", err)
		},
		Shutdown: func() {
			requestShutdown("client_request")
		},
	}).Handler()
	service := &http.Server{
		Addr:              *address,
		Handler:           accessLog(handler, logger),
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
		logger.Event(diagnosticlog.Info, "shutdown_requested", "graceful shutdown requested", "reason", reason)
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := service.Shutdown(ctx); err != nil {
			logger.Event(diagnosticlog.Error, "shutdown_failed", "graceful shutdown failed", "error", err)
		}
	}()

	listener, err := net.Listen("tcp", *address)
	if err != nil {
		failWithContext(logger, fmt.Errorf("listen: %w", err))
	}
	logger.Event(diagnosticlog.Info, "listening", "rules service is ready", "url", "http://"+listener.Addr().String())
	if err := service.Serve(listener); err != nil && !errors.Is(err, http.ErrServerClosed) {
		failWithContext(logger, fmt.Errorf("serve: %w", err))
	}
	logger.Event(diagnosticlog.Info, "stopped", "rules service stopped")
}

func failWithContext(logger *diagnosticlog.Logger, err error) {
	logger.Event(diagnosticlog.Error, "fatal", "rules service cannot continue", "error", err)
	os.Exit(1)
}

func captureUnhandledPanic(logger *diagnosticlog.Logger, crashDir, sessionID, version string) {
	panicValue := recover()
	if panicValue == nil {
		return
	}
	stack := debug.Stack()
	logger.Event(diagnosticlog.Error, "process_panic", "unhandled server panic", "error", panicValue)
	if report, err := crashreport.Write(crashDir, "server", sessionID, version, fmt.Sprint(panicValue), stack); err != nil {
		logger.Event(diagnosticlog.Error, "crash_report_failed", "could not persist server crash report", "error", err)
	} else {
		logger.Event(diagnosticlog.Error, "crash_report_created", "server crash report created", "file", filepath.Base(report.MetadataPath), "minidump", filepath.Base(report.DumpPath))
	}
	panic(panicValue)
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

func accessLog(next http.Handler, logger *diagnosticlog.Logger) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		started := time.Now()
		statusWriter := &responseStatusWriter{ResponseWriter: writer}
		next.ServeHTTP(statusWriter, request)
		status := statusWriter.status
		if status == 0 {
			status = http.StatusOK
		}
		logger.Event(diagnosticlog.Info, "http_request", "request completed",
			"method", request.Method,
			"path", request.URL.Path,
			"status", status,
			"duration_ms", time.Since(started).Milliseconds(),
		)
	})
}

type serverErrorWriter struct {
	logger   *diagnosticlog.Logger
	session  string
	version  string
	crashDir string
}

func (writer serverErrorWriter) Write(data []byte) (int, error) {
	message := strings.TrimSpace(string(data))
	writer.logger.Event(diagnosticlog.Error, "http_internal", message)
	if writer.crashDir != "" && strings.Contains(strings.ToLower(message), "panic") {
		if report, err := crashreport.Write(writer.crashDir, "server-http", writer.session, writer.version, message, data); err != nil {
			writer.logger.Event(diagnosticlog.Error, "crash_report_failed", "could not persist HTTP panic report", "error", err)
		} else {
			writer.logger.Event(diagnosticlog.Error, "crash_report_created", "HTTP panic report created", "file", filepath.Base(report.MetadataPath), "minidump", filepath.Base(report.DumpPath))
		}
	}
	return len(data), nil
}

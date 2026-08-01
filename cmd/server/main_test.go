package main

import (
	"bytes"
	"log"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestAccessLogContainsMetadataWithoutBodyOrQuery(t *testing.T) {
	var output bytes.Buffer
	logger := log.New(&output, "", 0)
	handler := accessLog(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		writer.WriteHeader(http.StatusTeapot)
	}), logger, "session-1", "0.1.0")
	request := httptest.NewRequest(http.MethodPost, "/api/v1/game/action?secret=query-value", strings.NewReader(`{"secret":"body-value"}`))
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)
	logged := output.String()
	for _, expected := range []string{
		"component=server",
		"event=http_request",
		`session="session-1"`,
		`version="0.1.0"`,
		`method="POST"`,
		`path="/api/v1/game/action"`,
		`status="418"`,
	} {
		if !strings.Contains(logged, expected) {
			t.Fatalf("log %q does not contain %q", logged, expected)
		}
	}
	if strings.Contains(logged, "query-value") || strings.Contains(logged, "body-value") {
		t.Fatalf("access log leaked request data: %q", logged)
	}
}

func TestServerErrorWriterPersistsPanicDiagnostic(t *testing.T) {
	var output bytes.Buffer
	crashDir := t.TempDir()
	writer := serverErrorWriter{
		logger:   log.New(&output, "", 0),
		session:  "session-1",
		version:  "0.1.0",
		crashDir: crashDir,
	}
	if _, err := writer.Write([]byte("http: panic serving 127.0.0.1: test panic\nstack")); err != nil {
		t.Fatal(err)
	}
	archives, err := filepath.Glob(filepath.Join(crashDir, "server-http-panic-*.log"))
	if err != nil {
		t.Fatal(err)
	}
	if len(archives) != 1 {
		t.Fatalf("panic diagnostic count = %d, want 1", len(archives))
	}
	data, err := os.ReadFile(archives[0])
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(data), "stack") || !strings.Contains(output.String(), "event=http_internal") {
		t.Fatalf("panic diagnostics were incomplete: file=%q log=%q", data, output.String())
	}
}

package diagnosticlog

import (
	"bytes"
	"log"
	"strings"
	"testing"
)

func TestLoggerFiltersAndRedacts(t *testing.T) {
	var output bytes.Buffer
	logger := New(log.New(&output, "", 0), Info, "server", "session", "test")
	logger.Event(Debug, "debug", "hidden")
	logger.Event(Info, "request", "url https://example.test/path?secret=value", "shutdown_token", "unsafe", "player_name", "Alice")
	logged := output.String()
	if strings.Contains(logged, "hidden") || strings.Contains(logged, "unsafe") || strings.Contains(logged, "Alice") || strings.Contains(logged, "secret=value") {
		t.Fatalf("log filtering or redaction failed: %q", logged)
	}
	for _, expected := range []string{`level=INFO`, `shutdown_token="[REDACTED]"`, `player_name="[REDACTED]"`, `https://example.test/path`} {
		if !strings.Contains(logged, expected) {
			t.Fatalf("log %q does not contain %q", logged, expected)
		}
	}
}

func TestParseLevelRejectsUnknownValue(t *testing.T) {
	if _, err := ParseLevel("verbose"); err == nil {
		t.Fatal("unknown log level was accepted")
	}
}

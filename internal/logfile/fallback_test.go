package logfile

import (
	"bytes"
	"errors"
	"testing"
)

type failingWriter struct{}

func (failingWriter) Write([]byte) (int, error) { return 0, errors.New("disk full") }

func TestFallbackWriterReportsFileFailureOnce(t *testing.T) {
	var fallback bytes.Buffer
	writer := &FallbackWriter{Primary: failingWriter{}, Fallback: &fallback}
	_, _ = writer.Write([]byte("first\n"))
	_, _ = writer.Write([]byte("second\n"))
	if bytes.Count(fallback.Bytes(), []byte("file output disabled")) != 1 {
		t.Fatalf("fallback warning count was not one: %q", fallback.String())
	}
	if !bytes.Contains(fallback.Bytes(), []byte("first")) || !bytes.Contains(fallback.Bytes(), []byte("second")) {
		t.Fatalf("fallback did not receive log events: %q", fallback.String())
	}
}

package logfile

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestRotatingWriterArchivesBySizeAndPrunes(t *testing.T) {
	t.Parallel()
	path := filepath.Join(t.TempDir(), "logs", "server.log")
	writer, err := NewRotatingWriter(path, 32, 2)
	if err != nil {
		t.Fatal(err)
	}
	for index := 0; index < 6; index++ {
		if _, err := writer.Write([]byte(strings.Repeat(string(rune('a'+index)), 20))); err != nil {
			t.Fatal(err)
		}
	}
	if err := writer.Close(); err != nil {
		t.Fatal(err)
	}
	archives, err := filepath.Glob(filepath.Join(filepath.Dir(path), "archived", "server-*.log"))
	if err != nil {
		t.Fatal(err)
	}
	if len(archives) != 2 {
		t.Fatalf("archive count = %d, want 2", len(archives))
	}
	if info, err := os.Stat(path); err != nil || info.Size() == 0 {
		t.Fatalf("active log was not preserved: info=%v err=%v", info, err)
	}
}

func TestRotatingWriterArchivesOversizedExistingFile(t *testing.T) {
	t.Parallel()
	path := filepath.Join(t.TempDir(), "logs", "server.log")
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(strings.Repeat("x", 40)), 0o644); err != nil {
		t.Fatal(err)
	}
	writer, err := NewRotatingWriter(path, 32, 5)
	if err != nil {
		t.Fatal(err)
	}
	defer writer.Close()
	archives, err := filepath.Glob(filepath.Join(filepath.Dir(path), "archived", "server-*.log"))
	if err != nil {
		t.Fatal(err)
	}
	if len(archives) != 1 {
		t.Fatalf("archive count = %d, want 1", len(archives))
	}
}

package crashreport

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestWriteRedactsCrashMetadata(t *testing.T) {
	report, err := Write(t.TempDir(), "server", "session", "test", "token=unsafe", []byte("password=unsafe\nstack"))
	if err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(report.MetadataPath)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(data), "unsafe") || !strings.Contains(string(data), "[REDACTED]") {
		t.Fatalf("crash metadata was not redacted: %s", data)
	}
}

func TestPruneRemovesOldMetadataAndMatchingDump(t *testing.T) {
	directory := t.TempDir()
	for index := 0; index < 3; index++ {
		stem := filepath.Join(directory, "server-crash-20260801-00000"+string(rune('0'+index)))
		if err := os.WriteFile(stem+".json", []byte("{}"), 0o644); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(stem+".dmp", []byte("dump"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if err := prune(directory, 2); err != nil {
		t.Fatal(err)
	}
	metadata, _ := filepath.Glob(filepath.Join(directory, "*.json"))
	dumps, _ := filepath.Glob(filepath.Join(directory, "*.dmp"))
	if len(metadata) != 2 || len(dumps) != 2 {
		t.Fatalf("pruned counts = metadata %d, dumps %d; want 2 each", len(metadata), len(dumps))
	}
}

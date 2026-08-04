// Package crashreport persists recoverable crash context and optional native dumps.
package crashreport

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"slices"
	"strings"
	"time"

	"narra/internal/diagnosticlog"
)

// Report describes files created for one recovered failure.
type Report struct {
	MetadataPath string
	DumpPath     string
}

// Write stores privacy-filtered metadata, a Go stack, and a Windows minidump when supported.
func Write(directory, component, session, version, summary string, stack []byte) (Report, error) {
	if strings.TrimSpace(directory) == "" {
		return Report{}, fmt.Errorf("crash directory cannot be empty")
	}
	if err := os.MkdirAll(directory, 0o755); err != nil {
		return Report{}, fmt.Errorf("create crash directory: %w", err)
	}
	timestamp := time.Now().UTC()
	stem := fmt.Sprintf("%s-crash-%s", safeName(component), timestamp.Format("20060102-150405.000000000"))
	metadataPath := filepath.Join(directory, stem+".json")
	metadata := struct {
		Application    string `json:"application"`
		Component      string `json:"component"`
		GeneratedAtUTC string `json:"generated_at_utc"`
		Session        string `json:"session"`
		Version        string `json:"version"`
		Summary        string `json:"summary"`
		PID            int    `json:"pid"`
		GOOS           string `json:"goos"`
		GOARCH         string `json:"goarch"`
		GoVersion      string `json:"go_version"`
		Stack          string `json:"stack"`
	}{
		Application:    "Narra",
		Component:      safeName(component),
		GeneratedAtUTC: timestamp.Format(time.RFC3339Nano),
		Session:        diagnosticlog.RedactText(session),
		Version:        diagnosticlog.RedactText(version),
		Summary:        diagnosticlog.RedactText(summary),
		PID:            os.Getpid(),
		GOOS:           runtime.GOOS,
		GOARCH:         runtime.GOARCH,
		GoVersion:      runtime.Version(),
		Stack:          diagnosticlog.RedactText(string(stack)),
	}
	encoded, err := json.MarshalIndent(metadata, "", "  ")
	if err != nil {
		return Report{}, fmt.Errorf("encode crash report: %w", err)
	}
	if err := os.WriteFile(metadataPath, encoded, 0o644); err != nil {
		return Report{}, fmt.Errorf("write crash report: %w", err)
	}
	report := Report{MetadataPath: metadataPath}
	dumpPath := filepath.Join(directory, stem+".dmp")
	if err := writeMiniDump(dumpPath); err == nil {
		report.DumpPath = dumpPath
	}
	if err := prune(directory, 5); err != nil {
		return report, fmt.Errorf("prune crash reports: %w", err)
	}
	return report, nil
}

func prune(directory string, keep int) error {
	entries, err := os.ReadDir(directory)
	if err != nil {
		return err
	}
	var reports []string
	for _, entry := range entries {
		if !entry.IsDir() && strings.Contains(entry.Name(), "-crash-") && strings.HasSuffix(entry.Name(), ".json") {
			reports = append(reports, entry.Name())
		}
	}
	slices.Sort(reports)
	for len(reports) > keep {
		metadataPath := filepath.Join(directory, reports[0])
		dumpPath := strings.TrimSuffix(metadataPath, ".json") + ".dmp"
		if err := os.Remove(metadataPath); err != nil && !os.IsNotExist(err) {
			return err
		}
		if err := os.Remove(dumpPath); err != nil && !os.IsNotExist(err) {
			return err
		}
		reports = reports[1:]
	}
	return nil
}

func safeName(value string) string {
	var result strings.Builder
	for _, character := range strings.ToLower(value) {
		if character >= 'a' && character <= 'z' || character >= '0' && character <= '9' || character == '-' || character == '_' {
			result.WriteRune(character)
		}
	}
	if result.Len() == 0 {
		return "process"
	}
	return result.String()
}

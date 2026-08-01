// Package logfile provides a small size-based rotating file writer.
package logfile

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"
)

// RotatingWriter appends to a log file and archives it after maxBytes.
type RotatingWriter struct {
	mu         sync.Mutex
	path       string
	archiveDir string
	maxBytes   int64
	backups    int
	file       *os.File
	size       int64
	now        func() time.Time
}

// NewRotatingWriter creates a writer whose archives live in a sibling archived directory.
func NewRotatingWriter(path string, maxBytes int64, backups int) (*RotatingWriter, error) {
	if strings.TrimSpace(path) == "" {
		return nil, errors.New("log path cannot be empty")
	}
	if maxBytes <= 0 {
		return nil, errors.New("maximum log size must be positive")
	}
	if backups < 0 {
		return nil, errors.New("backup count cannot be negative")
	}
	absolutePath, err := filepath.Abs(path)
	if err != nil {
		return nil, fmt.Errorf("resolve log path: %w", err)
	}
	writer := &RotatingWriter{
		path:       absolutePath,
		archiveDir: filepath.Join(filepath.Dir(absolutePath), "archived"),
		maxBytes:   maxBytes,
		backups:    backups,
		now:        time.Now,
	}
	if err := os.MkdirAll(filepath.Dir(writer.path), 0o755); err != nil {
		return nil, fmt.Errorf("create log directory: %w", err)
	}
	if err := os.MkdirAll(writer.archiveDir, 0o755); err != nil {
		return nil, fmt.Errorf("create log archive directory: %w", err)
	}
	if info, statErr := os.Stat(writer.path); statErr == nil && info.Size() >= maxBytes {
		if err := writer.archiveCurrent(); err != nil {
			return nil, err
		}
	} else if statErr != nil && !errors.Is(statErr, os.ErrNotExist) {
		return nil, fmt.Errorf("inspect log file: %w", statErr)
	}
	if err := writer.open(); err != nil {
		return nil, err
	}
	stem := strings.TrimSuffix(filepath.Base(writer.path), filepath.Ext(writer.path))
	if err := writer.prune(stem + "-"); err != nil {
		_ = writer.Close()
		return nil, err
	}
	return writer, nil
}

// Write implements io.Writer.
func (writer *RotatingWriter) Write(data []byte) (int, error) {
	writer.mu.Lock()
	defer writer.mu.Unlock()
	if writer.file == nil {
		return 0, os.ErrClosed
	}
	if writer.size > 0 && writer.size+int64(len(data)) > writer.maxBytes {
		if err := writer.rotate(); err != nil {
			return 0, err
		}
	}
	written, err := writer.file.Write(data)
	writer.size += int64(written)
	return written, err
}

// Close closes the active log file.
func (writer *RotatingWriter) Close() error {
	writer.mu.Lock()
	defer writer.mu.Unlock()
	if writer.file == nil {
		return nil
	}
	err := writer.file.Close()
	writer.file = nil
	return err
}

func (writer *RotatingWriter) open() error {
	file, err := os.OpenFile(writer.path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		return fmt.Errorf("open log file: %w", err)
	}
	info, err := file.Stat()
	if err != nil {
		_ = file.Close()
		return fmt.Errorf("inspect open log file: %w", err)
	}
	writer.file = file
	writer.size = info.Size()
	return nil
}

func (writer *RotatingWriter) rotate() error {
	if err := writer.file.Close(); err != nil {
		return fmt.Errorf("close log before rotation: %w", err)
	}
	writer.file = nil
	if err := writer.archiveCurrent(); err != nil {
		return err
	}
	return writer.open()
}

func (writer *RotatingWriter) archiveCurrent() error {
	info, err := os.Stat(writer.path)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("inspect log before rotation: %w", err)
	}
	if info.Size() == 0 {
		return os.Remove(writer.path)
	}
	stem := strings.TrimSuffix(filepath.Base(writer.path), filepath.Ext(writer.path))
	timestamp := writer.now().UTC().Format("20060102-150405.000000000")
	archivePath := filepath.Join(writer.archiveDir, fmt.Sprintf("%s-%s.log", stem, timestamp))
	for suffix := 1; ; suffix++ {
		_, statErr := os.Stat(archivePath)
		if errors.Is(statErr, os.ErrNotExist) {
			break
		}
		if statErr != nil {
			return fmt.Errorf("inspect log archive target: %w", statErr)
		}
		archivePath = filepath.Join(writer.archiveDir, fmt.Sprintf("%s-%s-%d.log", stem, timestamp, suffix))
	}
	if err := os.Rename(writer.path, archivePath); err != nil {
		return fmt.Errorf("archive log file: %w", err)
	}
	return writer.prune(stem + "-")
}

func (writer *RotatingWriter) prune(prefix string) error {
	entries, err := os.ReadDir(writer.archiveDir)
	if err != nil {
		return fmt.Errorf("read log archives: %w", err)
	}
	archives := make([]string, 0, len(entries))
	for _, entry := range entries {
		if !entry.IsDir() && strings.HasPrefix(entry.Name(), prefix) && strings.HasSuffix(entry.Name(), ".log") {
			archives = append(archives, entry.Name())
		}
	}
	sort.Strings(archives)
	for len(archives) > writer.backups {
		if err := os.Remove(filepath.Join(writer.archiveDir, archives[0])); err != nil {
			return fmt.Errorf("remove old log archive: %w", err)
		}
		archives = archives[1:]
	}
	return nil
}

var _ io.WriteCloser = (*RotatingWriter)(nil)

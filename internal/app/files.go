package app

import (
	"fmt"
	"os"
	"path/filepath"

	"narra/internal/domain"
)

// SaveFile writes and validates a save in the destination directory before
// replacing the previous file. The final rename stays on the same filesystem.
func (s *Session) SaveFile(path string) error {
	directory := filepath.Dir(path)
	if err := os.MkdirAll(directory, 0o755); err != nil {
		return fmt.Errorf("create save directory: %w", err)
	}
	temporary, err := os.CreateTemp(directory, ".narra-save-*.tmp")
	if err != nil {
		return fmt.Errorf("create temporary save: %w", err)
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)

	if err := s.Save(temporary); err != nil {
		temporary.Close()
		return fmt.Errorf("write temporary save: %w", err)
	}
	if err := temporary.Sync(); err != nil {
		temporary.Close()
		return fmt.Errorf("sync temporary save: %w", err)
	}
	if err := temporary.Close(); err != nil {
		return fmt.Errorf("close temporary save: %w", err)
	}
	if _, err := LoadFile(s.bundle, temporaryPath); err != nil {
		return fmt.Errorf("validate temporary save: %w", err)
	}
	if err := os.Rename(temporaryPath, path); err != nil {
		return fmt.Errorf("replace save: %w", err)
	}
	return nil
}

func LoadFile(bundle domain.Bundle, path string) (*Session, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	session, loadErr := LoadSession(bundle, file)
	closeErr := file.Close()
	if loadErr != nil {
		return nil, loadErr
	}
	if closeErr != nil {
		return nil, closeErr
	}
	return session, nil
}

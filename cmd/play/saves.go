package main

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"narra/internal/ai"
	"narra/internal/app"
	"narra/internal/director"
	"narra/internal/domain"
)

const (
	defaultSaveSlot = "quicksave"
	autosaveSlot    = "autosave"
)

var saveSlotPattern = regexp.MustCompile(`^[A-Za-z0-9_-]{1,40}$`)

type terminalGame struct {
	session       *app.Session
	saves         *terminalSaveStore
	autosave      bool
	dialogue      *ai.Service
	worldDirector director.Selector
	ai            *playAIRuntime
}

type terminalSaveStore struct {
	dir    string
	bundle domain.Bundle
}

type terminalSaveInfo struct {
	Slot     string
	Day      int
	Location string
	Modified time.Time
}

func (g *terminalGame) setWorldDirector(service *ai.Service) {
	if service == nil {
		g.worldDirector = nil
		if g.session != nil {
			g.session.SetWorldDirector(nil)
		}
		return
	}
	g.worldDirector = service
	if g.session != nil {
		g.session.SetWorldDirector(service)
	}
}

func newTerminalSaveStore(dir string, bundle domain.Bundle) (*terminalSaveStore, error) {
	dir = strings.TrimSpace(dir)
	if dir == "" {
		return nil, errors.New("save directory is empty")
	}
	abs, err := filepath.Abs(dir)
	if err != nil {
		return nil, fmt.Errorf("resolve save directory: %w", err)
	}
	return &terminalSaveStore{dir: filepath.Clean(abs), bundle: bundle}, nil
}

func validateSaveSlot(slot string) error {
	if !saveSlotPattern.MatchString(slot) {
		return errors.New("槽位名只能包含字母、数字、下划线或连字符，长度为 1—40 个字符")
	}
	return nil
}

func (s *terminalSaveStore) path(slot string) (string, error) {
	slot = strings.TrimSpace(slot)
	if err := validateSaveSlot(slot); err != nil {
		return "", err
	}
	return filepath.Join(s.dir, slot+".json"), nil
}

func (s *terminalSaveStore) exists(slot string) (bool, error) {
	path, err := s.path(slot)
	if err != nil {
		return false, err
	}
	_, err = os.Stat(path)
	if err == nil {
		return true, nil
	}
	if os.IsNotExist(err) {
		return false, nil
	}
	return false, err
}

func (s *terminalSaveStore) save(slot string, session *app.Session) error {
	path, err := s.path(slot)
	if err != nil {
		return err
	}
	return session.SaveFile(path)
}

func (s *terminalSaveStore) load(slot string) (*app.Session, error) {
	path, err := s.path(slot)
	if err != nil {
		return nil, err
	}
	return app.LoadFile(s.bundle, path)
}

func (s *terminalSaveStore) list() ([]terminalSaveInfo, error) {
	entries, err := os.ReadDir(s.dir)
	if os.IsNotExist(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	infos := make([]terminalSaveInfo, 0, len(entries))
	for _, entry := range entries {
		if entry.IsDir() || !strings.EqualFold(filepath.Ext(entry.Name()), ".json") {
			continue
		}
		slot := strings.TrimSuffix(entry.Name(), filepath.Ext(entry.Name()))
		if validateSaveSlot(slot) != nil {
			continue
		}
		session, err := s.load(slot)
		if err != nil {
			return nil, fmt.Errorf("load slot %s: %w", slot, err)
		}
		fileInfo, err := entry.Info()
		if err != nil {
			return nil, err
		}
		view := session.View()
		infos = append(infos, terminalSaveInfo{Slot: slot, Day: view.Day, Location: view.Location.Name, Modified: fileInfo.ModTime()})
	}
	sort.Slice(infos, func(i, j int) bool { return infos[i].Modified.After(infos[j].Modified) })
	return infos, nil
}

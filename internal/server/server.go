// Package server exposes the player application through a loopback JSON API.
package server

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sync"

	"fantu/internal/app"
	"fantu/internal/domain"
)

const APIVersion = "v1"

var validSlot = regexp.MustCompile(`^[A-Za-z0-9_-]{1,40}$`)

type GameServer struct {
	mu      sync.Mutex
	bundle  domain.Bundle
	saveDir string
	session *app.Session
}

type Response struct {
	APIVersion string          `json:"api_version"`
	View       *app.PlayerView `json:"view,omitempty"`
	Error      *APIError       `json:"error,omitempty"`
}

type APIError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

type newRequest struct {
	PlayerName string `json:"player_name"`
}

type actionRequest struct {
	ActionID string `json:"action_id"`
}

type slotRequest struct {
	Slot string `json:"slot"`
}

func New(bundle domain.Bundle, saveDir string) *GameServer {
	return &GameServer{bundle: bundle, saveDir: saveDir}
}

func (s *GameServer) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/api/v1/health", s.health)
	mux.HandleFunc("/api/v1/game", s.game)
	mux.HandleFunc("/api/v1/game/new", s.newGame)
	mux.HandleFunc("/api/v1/game/action", s.action)
	mux.HandleFunc("/api/v1/game/save", s.save)
	mux.HandleFunc("/api/v1/game/load", s.load)
	mux.HandleFunc("/api/v1/game/quit", s.quit)
	return securityHeaders(mux)
}

func (s *GameServer) health(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodGet {
		writeError(writer, http.StatusMethodNotAllowed, "method_not_allowed", "仅支持 GET")
		return
	}
	writeJSON(writer, http.StatusOK, Response{APIVersion: APIVersion})
}

func (s *GameServer) game(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodGet {
		writeError(writer, http.StatusMethodNotAllowed, "method_not_allowed", "仅支持 GET")
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.session == nil {
		writeError(writer, http.StatusConflict, "no_active_game", "当前没有进行中的游戏")
		return
	}
	view := s.session.View()
	writeJSON(writer, http.StatusOK, Response{APIVersion: APIVersion, View: &view})
}

func (s *GameServer) newGame(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodPost {
		writeError(writer, http.StatusMethodNotAllowed, "method_not_allowed", "仅支持 POST")
		return
	}
	var input newRequest
	if err := decodeJSON(request, &input); err != nil {
		writeError(writer, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	session, err := app.NewSession(s.bundle, app.DefaultBlackwindPlayer(input.PlayerName))
	if err != nil {
		writeError(writer, http.StatusInternalServerError, "new_game_failed", err.Error())
		return
	}
	s.mu.Lock()
	s.session = session
	view := session.View()
	s.mu.Unlock()
	writeJSON(writer, http.StatusCreated, Response{APIVersion: APIVersion, View: &view})
}

func (s *GameServer) action(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodPost {
		writeError(writer, http.StatusMethodNotAllowed, "method_not_allowed", "仅支持 POST")
		return
	}
	var input actionRequest
	if err := decodeJSON(request, &input); err != nil || input.ActionID == "" {
		if err == nil {
			err = errors.New("action_id 不能为空")
		}
		writeError(writer, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.session == nil {
		writeError(writer, http.StatusConflict, "no_active_game", "当前没有进行中的游戏")
		return
	}
	view, err := s.session.Execute(input.ActionID)
	if err != nil {
		writeError(writer, http.StatusBadRequest, "action_rejected", err.Error())
		return
	}
	writeJSON(writer, http.StatusOK, Response{APIVersion: APIVersion, View: &view})
}

func (s *GameServer) save(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodPost {
		writeError(writer, http.StatusMethodNotAllowed, "method_not_allowed", "仅支持 POST")
		return
	}
	var input slotRequest
	if err := decodeJSON(request, &input); err != nil {
		writeError(writer, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	path, err := s.slotPath(input.Slot)
	if err != nil {
		writeError(writer, http.StatusBadRequest, "invalid_slot", err.Error())
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.session == nil {
		writeError(writer, http.StatusConflict, "no_active_game", "当前没有进行中的游戏")
		return
	}
	if err := s.session.SaveFile(path); err != nil {
		writeError(writer, http.StatusInternalServerError, "save_failed", err.Error())
		return
	}
	view := s.session.View()
	writeJSON(writer, http.StatusOK, Response{APIVersion: APIVersion, View: &view})
}

func (s *GameServer) load(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodPost {
		writeError(writer, http.StatusMethodNotAllowed, "method_not_allowed", "仅支持 POST")
		return
	}
	var input slotRequest
	if err := decodeJSON(request, &input); err != nil {
		writeError(writer, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	path, err := s.slotPath(input.Slot)
	if err != nil {
		writeError(writer, http.StatusBadRequest, "invalid_slot", err.Error())
		return
	}
	session, err := app.LoadFile(s.bundle, path)
	if err != nil {
		status := http.StatusInternalServerError
		if errors.Is(err, os.ErrNotExist) {
			status = http.StatusNotFound
		}
		writeError(writer, status, "load_failed", err.Error())
		return
	}
	s.mu.Lock()
	s.session = session
	view := session.View()
	s.mu.Unlock()
	writeJSON(writer, http.StatusOK, Response{APIVersion: APIVersion, View: &view})
}

func (s *GameServer) quit(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodPost {
		writeError(writer, http.StatusMethodNotAllowed, "method_not_allowed", "仅支持 POST")
		return
	}
	s.mu.Lock()
	s.session = nil
	s.mu.Unlock()
	writeJSON(writer, http.StatusOK, Response{APIVersion: APIVersion})
}

func (s *GameServer) slotPath(slot string) (string, error) {
	if !validSlot.MatchString(slot) {
		return "", fmt.Errorf("存档槽只能包含字母、数字、下划线和连字符，长度 1 到 40")
	}
	return filepath.Join(s.saveDir, slot+".json"), nil
}

func decodeJSON(request *http.Request, target any) error {
	decoder := json.NewDecoder(io.LimitReader(request.Body, 1<<20))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		return fmt.Errorf("无效 JSON：%w", err)
	}
	return nil
}

func writeError(writer http.ResponseWriter, status int, code, message string) {
	writeJSON(writer, status, Response{APIVersion: APIVersion, Error: &APIError{Code: code, Message: message}})
}

func writeJSON(writer http.ResponseWriter, status int, response Response) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(response)
}

func securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		writer.Header().Set("Cache-Control", "no-store")
		writer.Header().Set("X-Content-Type-Options", "nosniff")
		next.ServeHTTP(writer, request)
	})
}

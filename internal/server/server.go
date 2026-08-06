// Package server exposes the player application through a loopback JSON API.
package server

import (
	"context"
	"crypto/subtle"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"

	"narra/internal/ai"
	"narra/internal/app"
	"narra/internal/domain"
)

const APIVersion = "v1"

var validSlot = regexp.MustCompile(`^[A-Za-z0-9_-]{1,40}$`)

type GameServer struct {
	mu            sync.Mutex
	bundle        domain.Bundle
	saveDir       string
	session       *app.Session
	shutdownToken string
	shutdown      func()
	dialogue      *ai.Service
	worldDirector *ai.Service
	dialogueMode  string
	configureAI   func(AISettings) (*ai.Service, string, error)
	reportError   func(string, error)
}

// Options configures process-level capabilities that are disabled in tests and embedded uses by default.
type Options struct {
	ShutdownToken string
	Shutdown      func()
	Dialogue      *ai.Service
	DialogueMode  string
	ConfigureAI   func(AISettings) (*ai.Service, string, error)
	ReportError   func(string, error)
}

type Response struct {
	APIVersion   string          `json:"api_version"`
	Scenario     *ScenarioInfo   `json:"scenario,omitempty"`
	View         *app.PlayerView `json:"view,omitempty"`
	Dialogue     *ai.Dialogue    `json:"dialogue,omitempty"`
	Capabilities *Capabilities   `json:"capabilities,omitempty"`
	AISettings   *AISettingsView `json:"ai_settings,omitempty"`
	Error        *APIError       `json:"error,omitempty"`
}

type ScenarioInfo struct {
	ID                   string                      `json:"id"`
	Title                string                      `json:"title"`
	ConversationDuration int                         `json:"conversation_duration"`
	Presentation         domain.ScenarioPresentation `json:"presentation"`
}

type Capabilities struct {
	AIDialogue      bool `json:"ai_dialogue"`
	AIWorldDirector bool `json:"ai_world_director"`
	AIConfiguration bool `json:"ai_configuration"`
}

type AISettings struct {
	Enabled bool   `json:"enabled"`
	APIKey  string `json:"api_key"`
	Model   string `json:"model"`
	BaseURL string `json:"base_url"`
}

type AISettingsView struct {
	Enabled bool   `json:"enabled"`
	Mode    string `json:"mode"`
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

type dialogueRequest struct {
	ActorID       string `json:"actor_id"`
	Situation     string `json:"situation,omitempty"`
	PlayerMessage string `json:"player_message,omitempty"`
}

func conversationDuration(bundle domain.Bundle) int {
	rule := bundle.Rules.Player.Conversation
	if !rule.Enabled {
		return 0
	}
	return bundle.Actions[rule.ActionID].Duration
}

type slotRequest struct {
	Slot string `json:"slot"`
}

type shutdownRequest struct {
	Token string `json:"token"`
}

func New(bundle domain.Bundle, saveDir string) *GameServer {
	return NewWithOptions(bundle, saveDir, Options{})
}

// NewWithOptions creates a game server with optional process-control capabilities.
func NewWithOptions(bundle domain.Bundle, saveDir string, options Options) *GameServer {
	return &GameServer{
		bundle:        bundle,
		saveDir:       filepath.Join(saveDir, bundle.Scenario.ID),
		shutdownToken: options.ShutdownToken,
		shutdown:      options.Shutdown,
		dialogue:      options.Dialogue,
		worldDirector: options.Dialogue,
		dialogueMode:  options.DialogueMode,
		configureAI:   options.ConfigureAI,
		reportError:   options.ReportError,
	}
}

func (s *GameServer) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/api/v1/health", s.health)
	mux.HandleFunc("/api/v1/game", s.game)
	mux.HandleFunc("/api/v1/game/new", s.newGame)
	mux.HandleFunc("/api/v1/game/action", s.action)
	mux.HandleFunc("/api/v1/game/dialogue", s.generateDialogue)
	mux.HandleFunc("/api/v1/settings/ai", s.configureAISettings)
	mux.HandleFunc("/api/v1/settings/ai/test", s.testAISettings)
	mux.HandleFunc("/api/v1/game/save", s.save)
	mux.HandleFunc("/api/v1/game/load", s.load)
	mux.HandleFunc("/api/v1/game/quit", s.quit)
	if s.shutdownToken != "" && s.shutdown != nil {
		mux.HandleFunc("/api/v1/server/shutdown", s.shutdownServer)
	}
	return securityHeaders(mux)
}

func (s *GameServer) shutdownServer(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodPost {
		writeError(writer, http.StatusMethodNotAllowed, "method_not_allowed", "仅支持 POST")
		return
	}
	var input shutdownRequest
	if err := decodeJSON(request, &input); err != nil {
		writeError(writer, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	if subtle.ConstantTimeCompare([]byte(input.Token), []byte(s.shutdownToken)) != 1 {
		writeError(writer, http.StatusForbidden, "invalid_shutdown_token", "关闭令牌无效")
		return
	}
	writeJSON(writer, http.StatusAccepted, Response{APIVersion: APIVersion})
	go s.shutdown()
}

func (s *GameServer) health(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodGet {
		writeError(writer, http.StatusMethodNotAllowed, "method_not_allowed", "仅支持 GET")
		return
	}
	s.mu.Lock()
	enabled := s.dialogue != nil && s.dialogue.Enabled()
	mode := s.dialogueMode
	configurable := s.configureAI != nil
	s.mu.Unlock()
	writeJSON(writer, http.StatusOK, Response{APIVersion: APIVersion,
		Scenario:     &ScenarioInfo{ID: s.bundle.Scenario.ID, Title: s.bundle.Scenario.Title, ConversationDuration: conversationDuration(s.bundle), Presentation: s.bundle.Presentation},
		Capabilities: &Capabilities{AIDialogue: enabled, AIWorldDirector: enabled, AIConfiguration: configurable},
		AISettings:   &AISettingsView{Enabled: enabled, Mode: mode},
	})
}

func (s *GameServer) configureAISettings(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodPut {
		writeError(writer, http.StatusMethodNotAllowed, "method_not_allowed", "仅支持 PUT")
		return
	}
	if s.configureAI == nil {
		writeError(writer, http.StatusNotImplemented, "ai_configuration_unavailable", "当前服务不支持运行时配置大模型")
		return
	}
	var input AISettings
	if err := decodeJSON(request, &input); err != nil {
		writeError(writer, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	dialogue, mode, err := s.configureAI(input)
	if err != nil {
		writeError(writer, http.StatusBadRequest, "invalid_ai_configuration", err.Error())
		return
	}
	s.mu.Lock()
	s.dialogue = dialogue
	s.worldDirector = dialogue
	s.dialogueMode = mode
	if s.session != nil {
		if dialogue == nil {
			s.session.SetWorldDirector(nil)
		} else {
			s.session.SetWorldDirector(dialogue)
		}
	}
	s.mu.Unlock()
	enabled := dialogue != nil && dialogue.Enabled()
	writeJSON(writer, http.StatusOK, Response{APIVersion: APIVersion,
		Capabilities: &Capabilities{AIDialogue: enabled, AIWorldDirector: enabled, AIConfiguration: true},
		AISettings:   &AISettingsView{Enabled: enabled, Mode: mode},
	})
}

func (s *GameServer) testAISettings(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodPost {
		writeError(writer, http.StatusMethodNotAllowed, "method_not_allowed", "仅支持 POST")
		return
	}
	if s.configureAI == nil {
		writeError(writer, http.StatusNotImplemented, "ai_configuration_unavailable", "当前服务不支持测试大模型配置")
		return
	}
	var input AISettings
	if err := decodeJSON(request, &input); err != nil {
		writeError(writer, http.StatusBadRequest, "invalid_request", "测试配置格式无效")
		return
	}
	input.Enabled = true
	service, mode, err := s.configureAI(input)
	if err != nil {
		s.reportInternalError("ai_connectivity_configuration", err)
		writeError(writer, http.StatusBadRequest, "invalid_ai_configuration", "模型配置不完整，请检查模型、接口地址和 API Key")
		return
	}
	if service == nil {
		err = errors.New("AI configurator returned no service")
		s.reportInternalError("ai_connectivity_configuration", err)
		writeError(writer, http.StatusBadRequest, "invalid_ai_configuration", "无法根据当前设置创建模型连接")
		return
	}
	if err := service.TestConnectivity(request.Context()); err != nil {
		s.reportInternalError("ai_connectivity_test", err)
		code, message := aiConnectivityError(err)
		writeError(writer, http.StatusBadGateway, code, message)
		return
	}
	writeJSON(writer, http.StatusOK, Response{APIVersion: APIVersion, AISettings: &AISettingsView{Enabled: true, Mode: mode}})
}

func (s *GameServer) reportInternalError(operation string, err error) {
	if s.reportError != nil && err != nil {
		s.reportError(operation, err)
	}
}

func aiConnectivityError(err error) (string, string) {
	message := strings.ToLower(err.Error())
	if errors.Is(err, context.DeadlineExceeded) || strings.Contains(message, "timeout") || strings.Contains(message, "timed out") {
		return "ai_connection_timeout", "连接模型超时，请检查网络、接口地址或稍后重试"
	}
	if strings.Contains(message, "401") || strings.Contains(message, "403") || strings.Contains(message, "unauthorized") || strings.Contains(message, "authentication") || strings.Contains(message, "api key") {
		return "ai_authentication_failed", "认证失败，请检查 API Key 是否正确并具有模型访问权限"
	}
	if strings.Contains(message, "no text block") || strings.Contains(message, "empty") {
		return "ai_empty_response", "接口已响应，但模型没有返回可用内容"
	}
	if strings.Contains(message, "decode") || strings.Contains(message, "json") || strings.Contains(message, "structured") || strings.Contains(message, "required structured") {
		return "ai_structured_output_failed", "接口可以访问，但当前模型不兼容所需的结构化输出"
	}
	return "ai_connection_failed", "无法使用当前模型配置，请检查接口地址、模型名称和网络状态"
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
	session, err := app.NewSession(s.bundle, app.DefaultPlayer(s.bundle, input.PlayerName))
	if err != nil {
		writeError(writer, http.StatusInternalServerError, "new_game_failed", err.Error())
		return
	}
	if s.worldDirector != nil {
		session.SetWorldDirector(s.worldDirector)
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
		s.reportInternalError("action", err)
		if strings.Contains(err.Error(), "world director") {
			writeError(writer, http.StatusBadRequest, "world_director_failed", "世界推演暂时没有完成，本次行动未生效，请重试")
			return
		}
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
	if s.worldDirector != nil {
		session.SetWorldDirector(s.worldDirector)
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

package server

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"reflect"
	"testing"
	"time"

	"narra/internal/ai"
	"narra/internal/app"
	"narra/internal/scenario"
)

func TestCommittedAPIContractMatchesResponseTypes(t *testing.T) {
	want, err := ContractJSON()
	if err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(filepath.Join("..", "..", "api", "v1-response.schema.json"))
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatal("API contract is stale; run go run ./cmd/schema")
	}
}

type serverDialogueProvider struct{}

func (serverDialogueProvider) GenerateDialogue(context.Context, ai.GenerationRequest) (ai.DialogueDraft, ai.GenerationMetadata, error) {
	return ai.DialogueDraft{
		Utterance: "先说说你的来意。", Emotion: "alert", DialogueAct: "question", ReferencedFacts: []string{},
	}, ai.GenerationMetadata{Model: "test"}, nil
}

func TestGameLifecycleAndSlotPersistence(t *testing.T) {
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	saveDir := t.TempDir()
	service := httptest.NewServer(New(bundle, saveDir).Handler())
	defer service.Close()

	response, status := request(t, service.URL, http.MethodGet, "/api/v1/health", nil)
	if status != http.StatusOK || response.APIVersion != APIVersion || response.Scenario == nil || response.Scenario.ID != bundle.Scenario.ID || response.Scenario.Presentation.WorldTitle == "" {
		t.Fatalf("health = %d %+v", status, response)
	}
	_, status = request(t, service.URL, http.MethodGet, "/api/v1/game", nil)
	if status != http.StatusConflict {
		t.Fatalf("game without session status = %d", status)
	}

	response, status = request(t, service.URL, http.MethodPost, "/api/v1/game/new", map[string]string{"player_name": "界面玩家"})
	if status != http.StatusCreated || response.View == nil || response.View.Player.Name != "界面玩家" {
		t.Fatalf("new game = %d %+v", status, response)
	}
	assertStructuredView(t, response.View)

	response, status = request(t, service.URL, http.MethodPost, "/api/v1/game/action", map[string]string{"action_id": "wait:next"})
	if status != http.StatusOK || response.View == nil || response.View.Day == 0 {
		t.Fatalf("action = %d %+v", status, response)
	}
	savedDay := response.View.Day

	_, status = request(t, service.URL, http.MethodPost, "/api/v1/game/save", map[string]string{"slot": "slot-1"})
	if status != http.StatusOK {
		t.Fatalf("save status = %d", status)
	}
	if _, err := os.Stat(filepath.Join(saveDir, bundle.Scenario.ID, "slot-1.json")); err != nil {
		t.Fatal(err)
	}
	_, status = request(t, service.URL, http.MethodPost, "/api/v1/game/quit", map[string]string{})
	if status != http.StatusOK {
		t.Fatalf("quit status = %d", status)
	}
	response, status = request(t, service.URL, http.MethodPost, "/api/v1/game/load", map[string]string{"slot": "slot-1"})
	if status != http.StatusOK || response.View == nil || response.View.Day != savedDay {
		t.Fatalf("load = %d %+v", status, response)
	}
}

func TestDialogueEndpointUsesModelWithoutChangingSession(t *testing.T) {
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	gameServer := NewWithOptions(bundle, t.TempDir(), Options{
		Dialogue: ai.NewService(serverDialogueProvider{}, ai.ServiceOptions{}),
	})
	service := httptest.NewServer(gameServer.Handler())
	defer service.Close()
	request(t, service.URL, http.MethodPost, "/api/v1/game/new", map[string]string{"player_name": "对话测试"})

	before := gameServer.session.View()
	response, status := request(t, service.URL, http.MethodPost, "/api/v1/game/dialogue", map[string]string{"actor_id": "N04"})
	after := gameServer.session.View()
	if status != http.StatusOK || response.Dialogue == nil || response.Dialogue.ActorID != "N04" || response.Dialogue.Source != "anthropic" {
		t.Fatalf("dialogue = %d %+v", status, response)
	}
	if before.Day != after.Day || len(gameServer.session.History()) != 0 {
		t.Fatalf("dialogue changed authoritative session: before=%d after=%d history=%v", before.Day, after.Day, gameServer.session.History())
	}
	response, status = request(t, service.URL, http.MethodPost, "/api/v1/game/dialogue", map[string]string{
		"actor_id": "N04", "player_message": "你准备如何核验？",
	})
	if status != http.StatusOK || response.Dialogue == nil {
		t.Fatalf("dialogue follow-up = %d %+v", status, response)
	}
	history := gameServer.session.DialogueHistory("N04", gameServer.session.DialogueRevision("N04"), 8)
	if len(history) != 2 || history[1].PlayerText != "你准备如何核验？" || gameServer.session.View().Day != before.Day {
		t.Fatalf("server dialogue history/state = %+v / %+v", history, gameServer.session.View())
	}
}

func TestDialogueEndpointReportsUnavailableWithoutModel(t *testing.T) {
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	gameServer := New(bundle, t.TempDir())
	service := httptest.NewServer(gameServer.Handler())
	defer service.Close()
	request(t, service.URL, http.MethodPost, "/api/v1/game/new", map[string]string{"player_name": "对话测试"})
	response, status := request(t, service.URL, http.MethodPost, "/api/v1/game/dialogue", map[string]string{"actor_id": "N04"})
	if status != http.StatusServiceUnavailable || response.Error == nil || response.Error.Code != "ai_unavailable" {
		t.Fatalf("unavailable dialogue = %d %+v", status, response)
	}
}

func TestAISettingsEndpointReconfiguresDialogueWithoutRestartingGame(t *testing.T) {
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	var received AISettings
	gameServer := NewWithOptions(bundle, t.TempDir(), Options{
		ConfigureAI: func(settings AISettings) (*ai.Service, string, error) {
			received = settings
			if !settings.Enabled {
				return nil, "disabled", nil
			}
			return ai.NewService(serverDialogueProvider{}, ai.ServiceOptions{}), "anthropic:" + settings.Model, nil
		},
	})
	service := httptest.NewServer(gameServer.Handler())
	defer service.Close()
	request(t, service.URL, http.MethodPost, "/api/v1/game/new", map[string]string{"player_name": "配置测试"})

	response, status := request(t, service.URL, http.MethodPut, "/api/v1/settings/ai", AISettings{
		Enabled: true, APIKey: "test-key", Model: "step-3.7-flash", BaseURL: "https://example.com/v1/messages",
	})
	if status != http.StatusOK || response.Capabilities == nil || !response.Capabilities.AIDialogue || response.AISettings == nil || !response.AISettings.Enabled {
		t.Fatalf("configure AI = %d %+v", status, response)
	}
	if received.APIKey != "test-key" || received.Model != "step-3.7-flash" {
		t.Fatalf("configurator received %+v", received)
	}
	response, status = request(t, service.URL, http.MethodPost, "/api/v1/game/dialogue", map[string]string{"actor_id": "N04"})
	if status != http.StatusOK || response.Dialogue == nil {
		t.Fatalf("dialogue after runtime configuration = %d %+v", status, response)
	}

	response, status = request(t, service.URL, http.MethodPut, "/api/v1/settings/ai", AISettings{Enabled: false})
	if status != http.StatusOK || response.Capabilities == nil || response.Capabilities.AIDialogue {
		t.Fatalf("disable AI = %d %+v", status, response)
	}
}

func TestSaveSlotsRejectPaths(t *testing.T) {
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	service := httptest.NewServer(New(bundle, t.TempDir()).Handler())
	defer service.Close()
	request(t, service.URL, http.MethodPost, "/api/v1/game/new", map[string]string{"player_name": "玩家"})
	response, status := request(t, service.URL, http.MethodPost, "/api/v1/game/save", map[string]string{"slot": "../escape"})
	if status != http.StatusBadRequest || response.Error == nil || response.Error.Code != "invalid_slot" {
		t.Fatalf("invalid slot = %d %+v", status, response)
	}
}

func TestShutdownRequiresTokenAndSignalsOnceAuthorized(t *testing.T) {
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	shutdown := make(chan struct{}, 1)
	service := httptest.NewServer(NewWithOptions(bundle, t.TempDir(), Options{
		ShutdownToken: "test-token",
		Shutdown: func() {
			shutdown <- struct{}{}
		},
	}).Handler())
	defer service.Close()

	response, status := request(t, service.URL, http.MethodPost, "/api/v1/server/shutdown", map[string]string{"token": "wrong"})
	if status != http.StatusForbidden || response.Error == nil || response.Error.Code != "invalid_shutdown_token" {
		t.Fatalf("invalid shutdown token = %d %+v", status, response)
	}
	select {
	case <-shutdown:
		t.Fatal("unauthorized shutdown invoked callback")
	default:
	}

	_, status = request(t, service.URL, http.MethodPost, "/api/v1/server/shutdown", map[string]string{"token": "test-token"})
	if status != http.StatusAccepted {
		t.Fatalf("authorized shutdown status = %d", status)
	}
	select {
	case <-shutdown:
	case <-time.After(time.Second):
		t.Fatal("authorized shutdown did not invoke callback")
	}
}

func assertStructuredView(t *testing.T, view *app.PlayerView) {
	t.Helper()
	if view.Presentation.Brand == "" || view.Presentation.WorldTitle == "" || view.Presentation.Objective == "" || len(view.Presentation.Resources) == 0 {
		t.Fatalf("scenario presentation = %+v", view.Presentation)
	}
	if len(view.KnownActors) == 0 || view.KnownActors[0].PublicProfile == "" || view.KnownActors[0].PublicRole == "" || len(view.KnownActors[0].PublicFocus) == 0 {
		t.Fatalf("public actor profiles = %+v", view.KnownActors)
	}
	foundTell := false
	for _, action := range view.AvailableActions {
		if action.Kind == "" {
			t.Fatalf("action lacks kind: %+v", action)
		}
		if action.Kind == "tell" {
			foundTell = true
			if action.TargetID == "" || action.TargetName == "" || action.FactID == "" || action.FactClaim == "" || action.Relevance == "" || action.Risk == "" {
				t.Fatalf("tell action lacks semantic fields: %+v", action)
			}
		}
	}
	if !foundTell {
		t.Fatal("initial view lacks tell action")
	}
}

func request(t *testing.T, baseURL, method, path string, payload any) (Response, int) {
	t.Helper()
	var body bytes.Buffer
	if payload != nil {
		if err := json.NewEncoder(&body).Encode(payload); err != nil {
			t.Fatal(err)
		}
	}
	req, err := http.NewRequest(method, baseURL+path, &body)
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Content-Type", "application/json")
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	var response Response
	if err := json.NewDecoder(res.Body).Decode(&response); err != nil {
		t.Fatal(err)
	}
	return response, res.StatusCode
}

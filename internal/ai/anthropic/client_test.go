package anthropic

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"fantu/internal/ai"
)

func TestNewRequiresCredentialsAndModel(t *testing.T) {
	if _, err := New(Config{Model: "test"}); err == nil {
		t.Fatal("client accepted an empty API key")
	}
	if _, err := New(Config{APIKey: "test"}); err == nil {
		t.Fatal("client accepted an empty model")
	}
}

func TestDialogueSchemaIsClosedAndComplete(t *testing.T) {
	if dialogueSchema["additionalProperties"] != false {
		t.Fatalf("dialogue schema is not closed: %+v", dialogueSchema)
	}
	required, ok := dialogueSchema["required"].([]string)
	if !ok || len(required) != 4 {
		t.Fatalf("dialogue schema required fields = %#v", dialogueSchema["required"])
	}
}

func TestGenerateDialogueUsesStructuredOutputAndDecodesResponse(t *testing.T) {
	var received map[string]any
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.URL.Path != "/v1/messages" {
			t.Errorf("request path = %q", request.URL.Path)
		}
		if err := json.NewDecoder(request.Body).Decode(&received); err != nil {
			t.Errorf("decode request: %v", err)
		}
		writer.Header().Set("Content-Type", "application/json")
		_, _ = writer.Write([]byte(`{"id":"msg_test","type":"message","role":"assistant","model":"test-model","content":[{"type":"text","text":"{\"utterance\":\"先说说你的来意。\",\"emotion\":\"alert\",\"dialogue_act\":\"question\",\"referenced_fact_ids\":[]}"}],"stop_reason":"end_turn","stop_sequence":null,"usage":{"input_tokens":12,"output_tokens":8}}`))
	}))
	defer server.Close()

	client, err := New(Config{APIKey: "test-key", Model: "test-model", BaseURL: server.URL + "/v1/messages", MaxRetries: 0})
	if err != nil {
		t.Fatal(err)
	}
	draft, metadata, err := client.GenerateDialogue(context.Background(), ai.GenerationRequest{System: "system", Input: "input"})
	if err != nil {
		t.Fatal(err)
	}
	if draft.Utterance != "先说说你的来意。" || draft.Emotion != "alert" || metadata.RequestID != "msg_test" {
		t.Fatalf("decoded dialogue = %+v, metadata = %+v", draft, metadata)
	}
	outputConfig, ok := received["output_config"].(map[string]any)
	if !ok {
		t.Fatalf("request has no output_config: %#v", received)
	}
	format, ok := outputConfig["format"].(map[string]any)
	if !ok || format["type"] != "json_schema" || format["schema"] == nil {
		t.Fatalf("structured output format = %#v", outputConfig)
	}
	if received["max_tokens"] != float64(1024) {
		t.Fatalf("max_tokens = %#v", received["max_tokens"])
	}
}

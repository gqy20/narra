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
	dialogueSchema := dialogueSchemaFor([]string{"F01"}, []string{"tell:N01:F01"})
	if dialogueSchema["additionalProperties"] != false {
		t.Fatalf("dialogue schema is not closed: %+v", dialogueSchema)
	}
	required, ok := dialogueSchema["required"].([]string)
	if !ok || len(required) != 5 {
		t.Fatalf("dialogue schema required fields = %#v", dialogueSchema["required"])
	}
}

func TestDialogueSchemaRestrictsFactReferences(t *testing.T) {
	schema := dialogueSchemaFor([]string{"F01", "F02"}, nil)
	properties := schema["properties"].(map[string]any)
	facts := properties["referenced_fact_ids"].(map[string]any)
	items := facts["items"].(map[string]any)
	if got := items["enum"].([]string); len(got) != 2 || got[0] != "F01" || got[1] != "F02" {
		t.Fatalf("fact enum = %#v", got)
	}
	empty := dialogueSchemaFor(nil, nil)["properties"].(map[string]any)["referenced_fact_ids"].(map[string]any)
	if empty["maxItems"] != 0 {
		t.Fatalf("empty fact list = %#v", empty)
	}
}

func TestWorldDirectiveSchemaRestrictsSelectionToCandidates(t *testing.T) {
	schema := worldDirectiveSchemaFor([]string{"open", "wait"})
	if schema["additionalProperties"] != false {
		t.Fatalf("schema is open: %+v", schema)
	}
	properties := schema["properties"].(map[string]any)
	ids := properties["directive_id"].(map[string]any)["enum"].([]string)
	if len(ids) != 2 || ids[0] != "open" || ids[1] != "wait" {
		t.Fatalf("directive enum = %#v", ids)
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
		_, _ = writer.Write([]byte(`{"id":"msg_test","type":"message","role":"assistant","model":"test-model","content":[{"type":"text","text":"{\"utterance\":\"先说说你的来意。\",\"emotion\":\"alert\",\"dialogue_act\":\"question\",\"referenced_fact_ids\":[],\"suggested_action_ids\":[]}"}],"stop_reason":"end_turn","stop_sequence":null,"usage":{"input_tokens":12,"output_tokens":8}}`))
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
	if outputConfig["effort"] != "low" {
		t.Fatalf("output effort = %#v", outputConfig["effort"])
	}
	format, ok := outputConfig["format"].(map[string]any)
	if !ok || format["type"] != "json_schema" || format["schema"] == nil {
		t.Fatalf("structured output format = %#v", outputConfig)
	}
	if received["max_tokens"] != float64(1024) {
		t.Fatalf("max_tokens = %#v", received["max_tokens"])
	}
}

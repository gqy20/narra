package app

import (
	"bytes"
	"context"
	"encoding/json"
	"strings"
	"testing"

	"narra/internal/director"
	"narra/internal/testsupport"
)

type saveWorldSelector struct{ calls int }

func (s *saveWorldSelector) SelectWorldDirective(_ context.Context, request director.SelectionRequest) (director.Selection, error) {
	s.calls++
	return director.Selection{DirectiveID: request.Candidates[0].DirectiveID, Reason: "存档测试选择", Source: "anthropic"}, nil
}

func TestSavePersistsAndReplaysAuthoritativeWorldDirectorChoices(t *testing.T) {
	bundle := testsupport.LoadOfficialWorld(t, "blackwind")
	session, err := NewSession(bundle, DefaultPlayer(bundle, "导演存档测试"))
	if err != nil {
		t.Fatal(err)
	}
	selector := &saveWorldSelector{}
	session.SetWorldDirector(selector)
	if _, err := session.Execute("wait:next"); err != nil {
		t.Fatal(err)
	}
	decisions := session.engine.State().DirectorDecisions
	if len(decisions) == 0 || decisions[0].Source != "anthropic" {
		t.Fatalf("AI decisions = %+v", decisions)
	}
	var saved bytes.Buffer
	if err := session.Save(&saved); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(saved.String(), `"director_replay"`) || !strings.Contains(saved.String(), `"complete": true`) || !strings.Contains(saved.String(), `"存档测试选择"`) {
		t.Fatalf("save omitted director audit: %s", saved.String())
	}
	restored, err := LoadSession(bundle, bytes.NewReader(saved.Bytes()))
	if err != nil {
		t.Fatal(err)
	}
	if got := restored.engine.State().DirectorDecisions; len(got) != len(decisions) || got[0].DirectiveID != decisions[0].DirectiveID || got[0].Reason != "存档测试选择" {
		t.Fatalf("replayed decisions = %+v", got)
	}
}

func TestLoadRejectsIncompleteOrStrippedDirectorReplay(t *testing.T) {
	bundle := testsupport.LoadOfficialWorld(t, "blackwind")
	session, err := NewSession(bundle, DefaultPlayer(bundle, "导演契约测试"))
	if err != nil {
		t.Fatal(err)
	}
	if _, err := session.Execute("wait:next"); err != nil {
		t.Fatal(err)
	}
	var saved bytes.Buffer
	if err := session.Save(&saved); err != nil {
		t.Fatal(err)
	}
	for name, mutate := range map[string]func(map[string]any){
		"missing": func(value map[string]any) { delete(value, "director_replay") },
		"incomplete": func(value map[string]any) {
			value["director_replay"].(map[string]any)["complete"] = false
		},
		"missing decisions": func(value map[string]any) {
			delete(value["director_replay"].(map[string]any), "decisions")
		},
		"stripped decisions": func(value map[string]any) {
			value["director_replay"].(map[string]any)["decisions"] = []any{}
		},
	} {
		t.Run(name, func(t *testing.T) {
			var value map[string]any
			if err := json.Unmarshal(saved.Bytes(), &value); err != nil {
				t.Fatal(err)
			}
			mutate(value)
			encoded, err := json.Marshal(value)
			if err != nil {
				t.Fatal(err)
			}
			if _, err := LoadSession(bundle, bytes.NewReader(encoded)); err == nil {
				t.Fatal("load accepted an incomplete world director replay")
			}
		})
	}
}

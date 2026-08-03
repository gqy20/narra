package app

import (
	"bytes"
	"context"
	"path/filepath"
	"strings"
	"testing"

	"fantu/internal/director"
	"fantu/internal/scenario"
)

type saveWorldSelector struct{ calls int }

func (s *saveWorldSelector) SelectWorldDirective(_ context.Context, request director.SelectionRequest) (director.Selection, error) {
	s.calls++
	return director.Selection{DirectiveID: request.Candidates[0].DirectiveID, Reason: "存档测试选择", Source: "anthropic"}, nil
}

func TestSavePersistsAndReplaysAuthoritativeWorldDirectorChoices(t *testing.T) {
	bundle, err := scenario.Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatal(err)
	}
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
	if !strings.Contains(saved.String(), `"director_decisions"`) || !strings.Contains(saved.String(), `"存档测试选择"`) {
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

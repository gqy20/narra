package app

import (
	"bytes"
	"encoding/json"
	"reflect"
	"strings"
	"testing"

	"fantu/internal/domain"
	"fantu/internal/scenario"
)

func testSession(t *testing.T) *Session {
	t.Helper()
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	session, err := NewSession(bundle, domain.PlayerConfig{
		ID: "P00", Name: "测试玩家", Location: "L01",
		Resources: map[string]int{"combat": 2, "support": 0, "spirit_stones": 100, "credit": 3},
		Items:     []string{"healing_pill"},
		Beliefs: []domain.Belief{{
			FactID: "F02", Claim: "青髓芝将在第24天成熟", Confidence: 1, Source: "坊市传言",
		}},
	})
	if err != nil {
		t.Fatal(err)
	}
	return session
}

func TestViewOnlyExposesPlayerKnowledge(t *testing.T) {
	session := testSession(t)
	view := session.View()
	if len(view.KnownFacts) != 1 || view.KnownFacts[0].FactID != "F02" {
		t.Fatalf("known facts = %+v", view.KnownFacts)
	}
	encoded, err := json.Marshal(view)
	if err != nil {
		t.Fatal(err)
	}
	for _, forbidden := range []string{"\"truth\"", "\"strategies\"", "\"score\"", "\"world_flags\""} {
		if bytes.Contains(encoded, []byte(forbidden)) {
			t.Fatalf("player view leaked private field %s: %s", forbidden, encoded)
		}
	}
}

func TestInitialCatalogIsDynamicAndRouteAware(t *testing.T) {
	view := testSession(t).View()
	ids := actionIDs(view.AvailableActions)
	for _, want := range []string{"verify:F02", "buy:M01:antidote", "move:L02", "move:L03", "cultivate", "wait"} {
		if !ids[want] {
			t.Errorf("missing action %s in %#v", want, ids)
		}
	}
	if ids["move:L04"] {
		t.Fatal("locked route to L04 should not be available")
	}
}

func TestBuyAndInvestigationUseAuthoritativeEngine(t *testing.T) {
	session := testSession(t)
	view, err := session.Execute("buy:M01:antidote")
	if err != nil {
		t.Fatal(err)
	}
	if view.Day != 1 || view.Player.Resources["spirit_stones"] != 80 || itemAmount(view.Player.Items, "antidote") != 1 {
		t.Fatalf("view after purchase = %+v", view.Player)
	}

	view, err = session.Execute("verify:F02")
	if err != nil {
		t.Fatal(err)
	}
	if !view.Player.Busy || len(view.AvailableActions) != 1 || view.AvailableActions[0].ID != "wait" {
		t.Fatalf("multi-day action state = %+v / %+v", view.Player, view.AvailableActions)
	}
	view, err = session.Execute("wait")
	if err != nil {
		t.Fatal(err)
	}
	if view.Day != 3 || view.Player.Busy || beliefConfidence(view.KnownFacts, "F02") != 3 {
		t.Fatalf("completed investigation view = %+v", view)
	}
}

func TestInvalidActionDoesNotAdvanceSession(t *testing.T) {
	session := testSession(t)
	if _, err := session.Execute("not-an-action"); err == nil {
		t.Fatal("invalid action unexpectedly succeeded")
	}
	if session.View().Day != 0 || len(session.History()) != 0 {
		t.Fatalf("invalid action changed session: day=%d history=%v", session.View().Day, session.History())
	}
}

func TestSaveLoadsByDeterministicReplay(t *testing.T) {
	session := testSession(t)
	for _, action := range []string{"buy:M01:antidote", "move:L02", "wait"} {
		if _, err := session.Execute(action); err != nil {
			t.Fatalf("execute %s: %v", action, err)
		}
	}
	var data bytes.Buffer
	if err := session.Save(&data); err != nil {
		t.Fatal(err)
	}
	if strings.Contains(data.String(), "world_flags") || strings.Contains(data.String(), "npcs") {
		t.Fatalf("save serialized engine internals: %s", data.String())
	}

	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	restored, err := LoadSession(bundle, &data)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(session.View(), restored.View()) || !reflect.DeepEqual(session.History(), restored.History()) {
		t.Fatalf("restored session differs\nwant: %+v\ngot:  %+v", session.View(), restored.View())
	}
}

func actionIDs(actions []AvailableAction) map[string]bool {
	result := make(map[string]bool, len(actions))
	for _, action := range actions {
		result[action.ID] = true
	}
	return result
}

func itemAmount(items []VisibleItem, id string) int {
	for _, item := range items {
		if item.ID == id {
			return item.Amount
		}
	}
	return 0
}

func beliefConfidence(beliefs []VisibleBelief, id string) int {
	for _, belief := range beliefs {
		if belief.FactID == id {
			return belief.Confidence
		}
	}
	return 0
}

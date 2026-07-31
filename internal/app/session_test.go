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
	if view.LastTurn == nil || view.LastTurn.Status != "completed" || !containsMessage(view.LastTurn.Messages, "灵石 -20") || !containsMessage(view.LastTurn.Messages, "解瘴丹 +1") {
		t.Fatalf("purchase feedback = %+v", view.LastTurn)
	}

	view, err = session.Execute("verify:F02")
	if err != nil {
		t.Fatal(err)
	}
	if !view.Player.Busy || len(view.AvailableActions) != 1 || view.AvailableActions[0].ID != "wait" {
		t.Fatalf("multi-day action state = %+v / %+v", view.Player, view.AvailableActions)
	}
	if view.LastTurn == nil || view.LastTurn.Status != "started" {
		t.Fatalf("investigation start feedback = %+v", view.LastTurn)
	}
	view, err = session.Execute("wait")
	if err != nil {
		t.Fatal(err)
	}
	if view.Day != 3 || view.Player.Busy || beliefConfidence(view.KnownFacts, "F02") != 3 {
		t.Fatalf("completed investigation view = %+v", view)
	}
	if view.LastTurn == nil || !containsMessage(view.LastTurn.Messages, "线索更新") {
		t.Fatalf("investigation completion feedback = %+v", view.LastTurn)
	}
}

func TestInitialGuidanceExplainsCoreDecisionWithoutLeakingTrueDate(t *testing.T) {
	view := testSession(t).View()
	joined := strings.Join(view.Guidance, " ")
	for _, want := range []string{"只是传闻", "解瘴丹", "路线"} {
		if !strings.Contains(joined, want) {
			t.Errorf("guidance %q does not mention %q", joined, want)
		}
	}
	if strings.Contains(joined, "第21天") {
		t.Fatalf("guidance leaked the true maturity date: %s", joined)
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

func TestSaveReplayAcceptsVersionOneHistoryAfterCoreResolution(t *testing.T) {
	session := testSession(t)
	executeUntilResolved(t, session)
	for session.engine.State().Day < 30 {
		if _, err := session.execute("wait", true); err != nil {
			t.Fatal(err)
		}
	}
	var data bytes.Buffer
	if err := session.Save(&data); err != nil {
		t.Fatal(err)
	}
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	restored, err := LoadSession(bundle, &data)
	if err != nil {
		t.Fatal(err)
	}
	if restored.engine.State().Day != 30 || restored.metrics.PostResultInputs != 9 {
		t.Fatalf("restored legacy history day/metrics = %d/%+v", restored.engine.State().Day, restored.metrics)
	}
}

func TestDemoObserverJourneyReachesExplainedEnding(t *testing.T) {
	session := testSession(t)
	executeUntilResolved(t, session)
	view := session.View()
	if !view.Resolved || view.Ended || view.Day != 21 || view.Ending == nil || !strings.Contains(view.Outcome, "李玄") {
		t.Fatalf("observer ending = %+v", view.Ending)
	}
	if !containsMessage(view.Ending.Highlights, "等待 21 天") {
		t.Fatalf("observer highlights = %v", view.Ending.Highlights)
	}
	if view.Metrics.CoreResultDay != 21 || view.Metrics.PostResultInputs != 0 || view.Metrics.DecisionInputs != 21 {
		t.Fatalf("observer metrics = %+v", view.Metrics)
	}
	if _, err := session.Execute("wait"); err == nil {
		t.Fatal("public session accepted input after core resolution")
	}
}

func TestDemoInvestigatorJourneyChangesPlayerKnowledge(t *testing.T) {
	session := testSession(t)
	executeMany(t, session, []string{"verify:F02", "wait"})
	executeUntilResolved(t, session)
	view := session.View()
	if !view.Resolved || beliefConfidence(view.KnownFacts, "F02") != 3 || beliefConfidence(view.KnownFacts, "F01") != 3 || beliefConfidence(view.KnownFacts, "F08") != 2 {
		t.Fatalf("investigator journey did not preserve verified knowledge: %+v", view.KnownFacts)
	}
	if view.Ending == nil || !containsMessage(view.Ending.Highlights, "核验情报 1 次") {
		t.Fatalf("investigator highlights = %+v", view.Ending)
	}
}

func TestDemoPreparedContenderCanWinCoreContest(t *testing.T) {
	session := testSession(t)
	actions := []string{
		"buy:M01:antidote",
		"cultivate", "wait", "wait",
		"cultivate", "wait", "wait",
		"cultivate", "wait", "wait",
		"cultivate", "wait", "wait",
		"cultivate", "wait", "wait",
		"wait",
		"move:L04", "wait",
		"move:L05",
	}
	actions = append(actions, "wait")
	executeMany(t, session, actions)
	view := session.View()
	if !view.Resolved || view.Day != 21 || !strings.Contains(view.Outcome, "测试玩家") {
		t.Fatalf("prepared contender outcome = %q", view.Outcome)
	}
	if view.Player.Resources["combat"] != 7 || view.Location.ID != "L05" {
		t.Fatalf("prepared contender state = %+v at %+v", view.Player, view.Location)
	}
}

func TestDemoMessengerJourneyRecordsDeliveredInfluence(t *testing.T) {
	session := testSession(t)
	actions := []string{"verify:F02", "wait", "move:L02", "tell:N03:F01"}
	for index, action := range actions {
		view, err := session.Execute(action)
		if err != nil {
			t.Fatalf("turn %d execute %s: %v", index+1, action, err)
		}
		if action == "tell:N03:F01" && (view.LastTurn == nil || !containsMessage(view.LastTurn.Messages, "情报已经送达沈砚秋")) {
			t.Fatalf("message delivery feedback = %+v", view.LastTurn)
		}
	}
	view, err := session.Execute("wait")
	if err != nil {
		t.Fatal(err)
	}
	if view.LastTurn == nil || !hasDecisionChange(view.LastTurn.Influence, "沈砚秋", "F01", 5) {
		t.Fatalf("day 5 immediate influence = %+v", view.LastTurn)
	}
	executeUntilResolved(t, session)
	view = session.View()
	if view.Ending == nil || !strings.Contains(view.Outcome, "沈砚秋") || !hasDecisionChange(view.Ending.Influence, "沈砚秋", "F01", 5) {
		t.Fatalf("messenger influence = %+v", view.Ending)
	}
	if view.Metrics.VisibleDecisionChanges < 1 || view.Metrics.CoreResultDay != 21 {
		t.Fatalf("messenger metrics = %+v", view.Metrics)
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

func containsMessage(messages []string, fragment string) bool {
	for _, message := range messages {
		if strings.Contains(message, fragment) {
			return true
		}
	}
	return false
}

func executeMany(t *testing.T, session *Session, actions []string) {
	t.Helper()
	for index, action := range actions {
		if _, err := session.Execute(action); err != nil {
			t.Fatalf("turn %d execute %s: %v", index+1, action, err)
		}
	}
}

func executeUntilResolved(t *testing.T, session *Session) {
	t.Helper()
	for !session.View().Resolved {
		if _, err := session.Execute("wait"); err != nil {
			t.Fatalf("wait until resolution: %v", err)
		}
	}
}

func hasDecisionChange(influences []VisibleInfluence, actorName, factID string, day int) bool {
	for _, influence := range influences {
		if influence.ActorName != actorName || influence.FactID != factID {
			continue
		}
		for _, change := range influence.Changes {
			if change.Day == day && change.WithInformation != "" && change.WithoutInformation != "" {
				return true
			}
		}
	}
	return false
}

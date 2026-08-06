package app

import (
	"context"
	"encoding/json"
	"strings"
	"testing"
)

func TestDialogueSnapshotRedactsPrivateBeliefsAndWorldInternals(t *testing.T) {
	session := testSession(t)
	snapshot, err := session.DialogueSnapshotFor("N01", "focus")
	if err != nil {
		t.Fatal(err)
	}
	if snapshot.Actor.ID != "N01" || snapshot.Revision == "" || snapshot.Situation != "focus" {
		t.Fatalf("snapshot identity = %+v", snapshot)
	}
	if snapshot.Scenario.Title == "" || snapshot.Scenario.Context == "" || snapshot.Scenario.PlayerAddress == "" || snapshot.Scenario.Style == "" {
		t.Fatalf("scenario dialogue presentation is incomplete: %+v", snapshot.Scenario)
	}
	if snapshot.Scenario.Locale != "zh-CN" || snapshot.Scenario.HardMaxCharacters != 80 || snapshot.Scenario.RumoredConfidence != "只是听说" || len(snapshot.Scenario.UncertaintyMarkers) == 0 || len(snapshot.Scenario.ForbiddenTerms) == 0 {
		t.Fatalf("scenario dialogue language policy is incomplete: %+v", snapshot.Scenario)
	}
	for _, claim := range snapshot.AllowedClaims {
		if claim.FactID == "F01" || claim.FactID == "F10" {
			t.Fatalf("private belief leaked into allowed claims: %+v", snapshot.AllowedClaims)
		}
	}
	encoded, err := json.Marshal(snapshot)
	if err != nil {
		t.Fatal(err)
	}
	text := string(encoded)
	for _, forbidden := range []string{"world_flags", "actor_flags", "strategy_id", "F10", "tell:N01:F02"} {
		if strings.Contains(text, forbidden) {
			t.Fatalf("dialogue snapshot leaked %q: %s", forbidden, text)
		}
	}
}

func TestDialogueSnapshotRequiresVisibleActorAndStableRevision(t *testing.T) {
	session := testSession(t)
	if _, err := session.DialogueSnapshotFor("N03", "focus"); err == nil {
		t.Fatal("dialogue snapshot accepted an actor at another location")
	}
	before, err := session.DialogueSnapshotFor("N04", "focus")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := session.Execute("wait"); err != nil {
		t.Fatal(err)
	}
	after, err := session.DialogueSnapshotFor("N04", "focus")
	if err != nil {
		t.Fatal(err)
	}
	if before.Revision == after.Revision {
		t.Fatalf("dialogue revision did not change after action: %q", before.Revision)
	}
}

func TestDialogueHistoryContinuesAcrossAuthoritativeTurns(t *testing.T) {
	session := testSession(t)
	revision := session.DialogueRevision("N04")
	if err := session.RecordDialogue(DialogueExchange{
		ActorID: "N04", Revision: revision, PlayerText: "先说说此地。", NPCText: "此地消息很多。",
		Emotion: "neutral", DialogueAct: "acknowledge",
	}); err != nil {
		t.Fatal(err)
	}
	if _, err := session.ExecuteConversationContext(context.Background(), "N04"); err != nil {
		t.Fatal(err)
	}
	currentRevision := session.DialogueRevision("N04")
	history := session.DialogueHistory("N04", currentRevision, 8)
	if len(history) != 1 || history[0].Revision != currentRevision || history[0].PlayerText != "先说说此地。" {
		t.Fatalf("cross-turn dialogue history = %+v", history)
	}
}

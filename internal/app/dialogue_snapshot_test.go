package app

import (
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
	for _, forbidden := range []string{"world_flags", "actor_flags", "strategy_id", "F10"} {
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

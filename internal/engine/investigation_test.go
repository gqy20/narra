package engine

import (
	"testing"

	"fantu/internal/domain"
)

func TestGenericInvestigationRequiresKnownLowConfidenceBelief(t *testing.T) {
	npc := domain.NPCConfig{ID: "N01", Name: "调查者", Location: "L01", Resources: map[string]int{"combat": 5}, Interests: []string{"qingsuizhi"}}
	bundle := plannerBundle(t, npc, 2)
	simulation := New(bundle)
	if got := simulation.genericInvestigationStrategies(simulation.state.NPCs[npc.ID]); len(got) != 0 {
		t.Fatalf("planner generated %d investigations without a known belief", len(got))
	}
	state, err := simulation.Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	for _, event := range state.Events {
		if event.ActionID == "verify" {
			t.Fatal("NPC investigated an unknown fact by reading world truth")
		}
	}
}

func TestGenericInvestigationProducesAuditableKnowledge(t *testing.T) {
	npc := domain.NPCConfig{
		ID: "N01", Name: "调查者", Location: "L01", Resources: map[string]int{"combat": 5},
		Interests: []string{"qingsuizhi"},
		Beliefs:   []domain.Belief{{FactID: "F02", Claim: "青髓芝将在第24天成熟", Confidence: 1, Source: "坊市传言"}},
	}
	state, err := New(plannerBundle(t, npc, 2)).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	beliefs := state.NPCs[npc.ID].Beliefs
	checks := map[string]int{"F02": 3, "F01": 3, "F08": 2}
	for factID, confidence := range checks {
		belief, ok := beliefs[factID]
		if !ok || belief.Confidence != confidence {
			t.Fatalf("belief %s = %#v, want confidence %d", factID, belief, confidence)
		}
		if belief.Source != "investigation:F02" || belief.LearnedOn != 2 {
			t.Fatalf("belief %s lost investigation provenance: %#v", factID, belief)
		}
	}
	if beliefs["F02"].Claim != bundleFactTruth(t, "F02") {
		t.Fatalf("F02 was not corrected to verified truth: %#v", beliefs["F02"])
	}
	assertGeneratedAction(t, state, "verify")
}

func TestGenericInvestigationRespectsDiscoverableFlag(t *testing.T) {
	npc := domain.NPCConfig{
		ID: "N01", Name: "调查者", Location: "L01", Resources: map[string]int{"combat": 5},
		Interests: []string{"qingsuizhi"},
		Beliefs:   []domain.Belief{{FactID: "F02", Confidence: 1}},
	}
	bundle := plannerBundle(t, npc, 2)
	fact := bundle.Facts["F02"]
	fact.Discoverable = false
	bundle.Facts["F02"] = fact
	state, err := New(bundle).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if got := state.NPCs[npc.ID].Beliefs["F02"].Confidence; got != 1 {
		t.Fatalf("non-discoverable belief confidence = %d, want unchanged 1", got)
	}
}

func TestGenericInvestigationCanBeDisabledPerScenario(t *testing.T) {
	npc := domain.NPCConfig{
		ID: "N01", Name: "调查者", Location: "L01", Resources: map[string]int{"combat": 5},
		Interests: []string{"qingsuizhi"},
		Beliefs:   []domain.Belief{{FactID: "F02", Confidence: 1}},
	}
	bundle := plannerBundle(t, npc, 2)
	bundle.Scenario.DisableGenericInvestigation = true
	state, err := New(bundle).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if got := state.NPCs[npc.ID].Beliefs["F02"].Confidence; got != 1 {
		t.Fatalf("disabled generic investigation changed confidence to %d", got)
	}
	for _, event := range state.Events {
		if event.ActionID == "verify" {
			t.Fatal("disabled generic investigation still generated a verify action")
		}
	}
}

func TestGenericInvestigationRequiresRelevantTopic(t *testing.T) {
	npc := domain.NPCConfig{
		ID: "N01", Name: "调查者", Location: "L01", Resources: map[string]int{"combat": 5}, Interests: []string{"market"},
		Beliefs: []domain.Belief{{FactID: "F02", Confidence: 1}},
	}
	state, err := New(plannerBundle(t, npc, 2)).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if got := state.NPCs[npc.ID].Beliefs["F02"].Confidence; got != 1 {
		t.Fatalf("irrelevant belief confidence = %d, want unchanged 1", got)
	}
}

func bundleFactTruth(t *testing.T, factID string) string {
	t.Helper()
	bundle := loadBlackwind(t)
	return bundle.Facts[factID].Truth
}

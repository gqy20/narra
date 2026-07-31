package engine

import (
	"strings"
	"testing"

	"fantu/internal/domain"
)

func claimStrategy(id, actorID string) domain.Strategy {
	return domain.Strategy{
		ID: id, ActionID: "explore", Description: actorID + "争夺青髓芝", FromDay: 1, UntilDay: 1, Duration: 1, Once: true,
		Costs:   map[string]int{"spirit_stones": 5},
		Score:   domain.ScoreInput{Goal: 1},
		Effects: []domain.Effect{{Type: "transfer_unique", FromID: "L05", TargetID: actorID, Key: "qingsuizhi"}},
	}
}

func TestSameDayUniqueClaimHasOneWinnerAndRefundsLoser(t *testing.T) {
	npcs := []domain.NPCConfig{
		{ID: "N01", Name: "强者", Location: "L05", Resources: map[string]int{"combat": 5, "spirit_stones": 5}, Strategies: []domain.Strategy{claimStrategy("claim-strong", "N01")}},
		{ID: "N02", Name: "弱者", Location: "L05", Resources: map[string]int{"combat": 2, "spirit_stones": 5}, Strategies: []domain.Strategy{claimStrategy("claim-weak", "N02")}},
	}
	bundle := plannerBundle(t, npcs[0], 1)
	bundle.NPCs = npcs
	state, err := New(bundle).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if owner := state.Items["qingsuizhi"]; owner != "N01" {
		t.Fatalf("unique item owner = %s, want stronger N01", owner)
	}
	if got := state.NPCs["N01"].Resources["spirit_stones"]; got != 0 {
		t.Fatalf("winner cost = %d, want consumed", got)
	}
	if got := state.NPCs["N02"].Resources["spirit_stones"]; got != 5 {
		t.Fatalf("loser refund = %d, want 5", got)
	}
	for _, event := range state.Events {
		if event.ActorID == "N02" && event.Type == "action_failed" && strings.Contains(event.Description, "竞争失败") {
			if event.StrategyID != "claim-weak" || event.IntentID == "" {
				t.Fatalf("competition failure lacks causal IDs: %#v", event)
			}
			return
		}
	}
	t.Fatal("loser did not receive a competition failure event")
}

func TestPendingUniqueClaimFailsAfterSourceOwnerChanges(t *testing.T) {
	claimer := domain.NPCConfig{
		ID: "N01", Name: "迟到者", Location: "L05", Resources: map[string]int{"combat": 5, "spirit_stones": 5},
		Strategies: []domain.Strategy{{
			ID: "slow-claim", ActionID: "explore", Description: "缓慢采摘", FromDay: 1, UntilDay: 3, Duration: 2, Once: true,
			Costs:   map[string]int{"spirit_stones": 5},
			Effects: []domain.Effect{{Type: "transfer_unique", FromID: "L05", TargetID: "N01", Key: "qingsuizhi"}},
		}},
	}
	winner := domain.NPCConfig{ID: "N02", Name: "先到者", Location: "L05", Resources: map[string]int{"combat": 5}}
	bundle := plannerBundle(t, claimer, 3)
	bundle.NPCs = []domain.NPCConfig{claimer, winner}
	bundle.Scenario.FixedEvents = []domain.FixedEvent{{
		ID: "early-transfer", Day: 2, Timing: "start", Description: "先到者取走灵药",
		Effects: []domain.Effect{{Type: "transfer_unique", FromID: "L05", TargetID: "N02", Key: "qingsuizhi"}},
	}}
	state, err := New(bundle).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if owner := state.Items["qingsuizhi"]; owner != "N02" {
		t.Fatalf("stale plan stole item back, owner = %s", owner)
	}
	if got := state.NPCs["N01"].Resources["spirit_stones"]; got != 5 {
		t.Fatalf("stale claim refund = %d, want 5", got)
	}
	if state.NPCs["N01"].Completed["slow-claim"] {
		t.Fatal("stale claim was marked completed")
	}
	decisions := 0
	for _, decision := range state.Decisions {
		if decision.ActorID == "N01" {
			decisions++
		}
	}
	if decisions != 1 {
		t.Fatalf("stale strategy was selected again after source moved: decisions=%d", decisions)
	}
	for _, event := range state.Events {
		if event.ActorID == "N01" && event.Type == "action_failed" && strings.Contains(event.Description, "当前归属") {
			if event.ParentEventID == "" {
				t.Fatalf("multi-day failure lacks start-event parent: %#v", event)
			}
			return
		}
	}
	t.Fatal("stale unique claim did not fail audibly")
}

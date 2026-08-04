package engine

import (
	"testing"

	"narra/internal/domain"
)

func TestInformationPropagationRespectsLocationDelayAndDistortion(t *testing.T) {
	bundle := loadBlackwind(t)
	bundle.Scenario.Duration = 2
	bundle.Scenario.FixedEvents = nil
	bundle.Scenario.Contest.Day = 3
	bundle.Scenario.Phases = []domain.SituationPhase{{ID: "test", Name: "测试", FromDay: 1, ToDay: 2}}
	delete(bundle.Actions, "verify")
	bundle.NPCs = []domain.NPCConfig{
		{
			ID: "N01", Name: "传播者", Faction: "A", Location: "L01", Resources: map[string]int{},
			Strategies: []domain.Strategy{{
				ID: "broadcast", ActionID: "spread", Description: "发布地点消息", FromDay: 1, UntilDay: 1, Once: true,
				Score: domain.ScoreInput{Goal: 5}, Effects: []domain.Effect{{
					Type: "set_belief", TargetID: "*", FactID: "F01", Claim: "延迟消息", Confidence: 3,
					EvidenceStrength: 3, Propagation: "location", DelayDays: 1, Distortion: 1, Secrecy: 1,
				}},
			}},
		},
		{ID: "N02", Name: "同地接收者", Faction: "B", Location: "L01", Resources: map[string]int{}},
		{ID: "N03", Name: "异地角色", Faction: "A", Location: "L02", Resources: map[string]int{}},
	}

	simulation := New(bundle)
	day1, err := simulation.Step(nil)
	if err != nil {
		t.Fatalf("day 1: %v", err)
	}
	if _, ok := day1.NPCs["N02"].Beliefs["F01"]; ok {
		t.Fatal("delayed information arrived on the send day")
	}
	day2, err := simulation.Step(nil)
	if err != nil {
		t.Fatalf("day 2: %v", err)
	}
	belief, ok := day2.NPCs["N02"].Beliefs["F01"]
	if !ok || belief.Confidence != 2 || belief.EvidenceStrength != 2 || belief.LearnedOn != 2 || belief.Secrecy != 1 {
		t.Fatalf("delivered belief = %+v, want delayed and distorted confidence/strength 2", belief)
	}
	if _, ok := day2.NPCs["N03"].Beliefs["F01"]; ok {
		t.Fatal("location-scoped information reached another location")
	}
	for _, event := range day2.Events {
		if event.Type == "information_delivered" && event.TargetID == "N02" && event.ParentEventID != "" && belief.SourceEventID == event.ID {
			return
		}
	}
	t.Fatal("delivery event did not preserve its parent and belief provenance")
}

func TestPrivateInformationOnlyReachesExplicitTarget(t *testing.T) {
	bundle := loadBlackwind(t)
	bundle.Scenario.Duration = 1
	bundle.Scenario.FixedEvents = nil
	bundle.Scenario.Contest.Day = 2
	bundle.Scenario.Phases = []domain.SituationPhase{{ID: "test", Name: "测试", FromDay: 1, ToDay: 1}}
	delete(bundle.Actions, "verify")
	bundle.NPCs = []domain.NPCConfig{
		{
			ID: "N01", Name: "发送者", Faction: "A", Location: "L01", Resources: map[string]int{},
			Strategies: []domain.Strategy{{
				ID: "whisper", ActionID: "inquire", Description: "私下告知", FromDay: 1, UntilDay: 1, Once: true,
				Score: domain.ScoreInput{Goal: 5}, Effects: []domain.Effect{{
					Type: "set_belief", TargetID: "N02", FactID: "F01", Claim: "秘密", Confidence: 3,
					Propagation: "private", Secrecy: 3,
				}},
			}},
		},
		{ID: "N02", Name: "接收者", Faction: "A", Location: "L01", Resources: map[string]int{}},
		{ID: "N03", Name: "旁观者", Faction: "A", Location: "L01", Resources: map[string]int{}},
	}
	state, err := New(bundle).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if got := state.NPCs["N02"].Beliefs["F01"].Secrecy; got != 3 {
		t.Fatalf("private belief secrecy = %d, want 3", got)
	}
	if _, ok := state.NPCs["N03"].Beliefs["F01"]; ok {
		t.Fatal("private information leaked to an unaddressed actor")
	}
}

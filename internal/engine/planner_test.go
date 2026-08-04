package engine

import (
	"testing"

	"narra/internal/domain"
)

func plannerBundle(t *testing.T, npc domain.NPCConfig, duration int) domain.Bundle {
	t.Helper()
	bundle := loadBlackwind(t)
	bundle.NPCs = []domain.NPCConfig{npc}
	bundle.Scenario.Duration = duration
	bundle.Scenario.FixedEvents = nil
	bundle.Scenario.Phases = []domain.SituationPhase{{ID: "test", Name: "测试", FromDay: 1, ToDay: duration}}
	bundle.Scenario.Contest.Day = duration + 1
	return bundle
}

func TestGenericPlannerCultivatesDuringSafeIdleWindow(t *testing.T) {
	npc := domain.NPCConfig{ID: "N01", Name: "测试角色", Location: "L01", Resources: map[string]int{"combat": 2}, Personality: domain.Personality{Ambition: 4}}
	state, err := New(plannerBundle(t, npc, 3)).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if got := state.NPCs[npc.ID].Resources["combat"]; got != 3 {
		t.Fatalf("combat = %d, want 3 after cultivation", got)
	}
	assertGeneratedAction(t, state, "cultivate")
}

func TestGenericPlannerHealsInjuredIdleNPC(t *testing.T) {
	npc := domain.NPCConfig{ID: "N01", Name: "测试角色", Location: "L01", Injury: 2, Resources: map[string]int{"combat": 5}}
	state, err := New(plannerBundle(t, npc, 3)).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if got := state.NPCs[npc.ID].Injury; got != 1 {
		t.Fatalf("injury = %d, want 1 after healing", got)
	}
	assertGeneratedAction(t, state, "heal")
}

func TestGenericPlannerBuysMissingAntidote(t *testing.T) {
	npc := domain.NPCConfig{
		ID: "N01", Name: "测试角色", Location: "L01", Resources: map[string]int{"combat": 5, "spirit_stones": 20},
		Beliefs: []domain.Belief{{FactID: "F01", Confidence: 2}},
	}
	state, err := New(plannerBundle(t, npc, 1)).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if state.NPCs[npc.ID].Items["antidote"] != 1 || state.NPCs[npc.ID].Resources["spirit_stones"] != 0 {
		t.Fatalf("generic purchase did not settle: items=%v resources=%v", state.NPCs[npc.ID].Items, state.NPCs[npc.ID].Resources)
	}
	assertGeneratedAction(t, state, "buy")
}

func TestAuthoredStrategyWinsAndFutureWindowIsNotBlocked(t *testing.T) {
	npc := domain.NPCConfig{
		ID: "N01", Name: "测试角色", Location: "L01", Resources: map[string]int{"combat": 2},
		Strategies: []domain.Strategy{{
			ID: "authored", ActionID: "inquire", Description: "执行场景计划", FromDay: 2, UntilDay: 2, Once: true,
			Effects: []domain.Effect{{Type: "set_flag", Key: "authored_done", Value: "true"}},
		}},
	}
	simulation := New(plannerBundle(t, npc, 2))
	day1, err := simulation.Step(nil)
	if err != nil {
		t.Fatalf("day 1: %v", err)
	}
	if day1.NPCs[npc.ID].Pending != nil {
		t.Fatal("generic cultivation blocked a future authored strategy window")
	}
	day2, err := simulation.Step(nil)
	if err != nil {
		t.Fatalf("day 2: %v", err)
	}
	if !day2.ActorFlag("N01", "authored_done") {
		t.Fatal("authored strategy did not run")
	}
	for _, event := range day2.Events {
		if event.ActionID == "inquire" && event.Description == "执行场景计划" {
			return
		}
	}
	t.Fatal("authored action event missing")
}

func TestUnifiedPlanningLetsGenericAndAuthoredStrategiesCompete(t *testing.T) {
	npc := domain.NPCConfig{
		ID: "N01", Name: "测试角色", Location: "L01", Injury: 2, Resources: map[string]int{"combat": 4},
		Strategies: []domain.Strategy{{
			ID: "authored-low", ActionID: "inquire", Description: "低分场景计划", FromDay: 1, UntilDay: 1, Once: true,
			Score: domain.ScoreInput{Goal: 1}, Effects: []domain.Effect{{Type: "set_flag", Key: "authored_done", Value: "true"}},
		}},
	}
	bundle := plannerBundle(t, npc, 3)
	bundle.Scenario.PlanningMode = "unified_score"
	state, err := New(bundle).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if got := state.NPCs[npc.ID].Injury; got != 1 {
		t.Fatalf("injury = %d, want generic heal to win unified scoring", got)
	}
	if state.ActorFlag(npc.ID, "authored_done") {
		t.Fatal("lower-scored authored strategy unexpectedly won")
	}
	decision := state.Decisions[0]
	if len(decision.Choices) < 2 || !decision.Choices[0].Generated || decision.Choices[1].Generated {
		t.Fatalf("unified candidates = %+v, want generated then authored", decision.Choices)
	}
}

func TestAuthoredPriorityDoesNotExposeGenericCompetitor(t *testing.T) {
	npc := domain.NPCConfig{
		ID: "N01", Name: "测试角色", Location: "L01", Injury: 2, Resources: map[string]int{"combat": 4},
		Strategies: []domain.Strategy{{
			ID: "authored-low", ActionID: "inquire", Description: "低分场景计划", FromDay: 1, UntilDay: 1, Once: true,
			Score: domain.ScoreInput{Goal: 1}, Effects: []domain.Effect{{Type: "set_flag", Key: "authored_done", Value: "true"}},
		}},
	}
	state, err := New(plannerBundle(t, npc, 1)).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if !state.ActorFlag(npc.ID, "authored_done") || state.NPCs[npc.ID].Injury != 2 {
		t.Fatal("authored_priority did not preserve authored-first behavior")
	}
	if len(state.Decisions[0].Choices) != 1 || state.Decisions[0].Choices[0].Generated {
		t.Fatalf("authored priority candidates = %+v", state.Decisions[0].Choices)
	}
}

func TestStructuredGoalPriorityAddsAlignmentScore(t *testing.T) {
	goals := []domain.Goal{{Type: "profit", Priority: 2}, {Type: "avoid", Priority: 5}}
	if got := goalAlignment(goals, []string{"profit", "avoid"}); got != 5 {
		t.Fatalf("goal alignment = %d, want highest matching priority 5", got)
	}
	if got := goalAlignment(goals, []string{"status"}); got != 0 {
		t.Fatalf("unmatched goal alignment = %d, want 0", got)
	}
}

func TestGenericSupplyAndNavigationSharePersistentPlan(t *testing.T) {
	npc := domain.NPCConfig{
		ID: "N01", Name: "测试角色", Location: "L01", Resources: map[string]int{"combat": 4, "spirit_stones": 20},
		Beliefs: []domain.Belief{{FactID: "F01", Confidence: 3}}, Personality: domain.Personality{Ambition: 4},
		Goals: []domain.Goal{{Type: "acquire", TargetID: "qingsuizhi", Priority: 5}},
	}
	bundle := plannerBundle(t, npc, 6)
	bundle.Scenario.FixedEvents = []domain.FixedEvent{{
		ID: "open", Day: 1, Timing: "start", Description: "开放路线",
		Effects: []domain.Effect{{Type: "set_flag", TargetID: "world", Key: "valley_open", Value: "true"}},
	}}
	state, err := New(bundle).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if state.NPCs[npc.ID].Location != "L05" {
		t.Fatalf("location = %s, want L05", state.NPCs[npc.ID].Location)
	}
	planIDs := make(map[string]bool)
	steps := make(map[string]bool)
	for _, event := range state.Events {
		if event.ActorID == npc.ID && event.PlanID != "" && (event.Type == "action" || event.Type == "action_start") {
			planIDs[event.PlanID] = true
			steps[event.PlanStepID] = true
		}
	}
	if len(planIDs) != 1 || !steps["supply"] || !steps["navigate"] || !steps["enter"] {
		t.Fatalf("plan audit ids=%v steps=%v, want one plan with supply/navigate/enter", planIDs, steps)
	}
	for planID := range planIDs {
		plan := state.NPCs[npc.ID].Plans[planID]
		if plan == nil || plan.Status != "completed" || state.NPCs[npc.ID].ActivePlanID != "" {
			t.Fatalf("completed plan = %+v active=%q", plan, state.NPCs[npc.ID].ActivePlanID)
		}
	}
}

func TestGenericPlannerExploresAlongAvailableRoutes(t *testing.T) {
	npc := domain.NPCConfig{
		ID: "N01", Name: "测试角色", Location: "L01", Resources: map[string]int{"combat": 4}, Items: []string{"antidote"},
		Beliefs: []domain.Belief{{FactID: "F01", Confidence: 3}}, Personality: domain.Personality{Ambition: 4},
	}
	bundle := plannerBundle(t, npc, 4)
	bundle.Scenario.Contest.Day = 5
	simulation := New(bundle)
	simulation.state.SetWorldFlag("valley_open", true)
	state, err := simulation.Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if got := state.NPCs[npc.ID].Location; got != "L05" {
		t.Fatalf("location = %s, want L05 after two route steps", got)
	}
	completed := 0
	for _, event := range state.Events {
		if event.Type == "action" && event.ActionID == "explore" {
			completed++
		}
	}
	if completed != 2 {
		t.Fatalf("completed explore steps = %d, want 2", completed)
	}
}

func TestGenericPlannerDoesNotCrossRouteWithoutRequiredItem(t *testing.T) {
	npc := domain.NPCConfig{
		ID: "N01", Name: "测试角色", Location: "L01", Resources: map[string]int{"combat": 4},
		Beliefs: []domain.Belief{{FactID: "F01", Confidence: 3}}, Personality: domain.Personality{Ambition: 4},
	}
	bundle := plannerBundle(t, npc, 1)
	bundle.Scenario.Contest.Day = 5
	simulation := New(bundle)
	simulation.state.SetWorldFlag("valley_open", true)
	state, err := simulation.Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if got := state.NPCs[npc.ID].Location; got != "L01" {
		t.Fatalf("location = %s, route should require antidote", got)
	}
}

func TestGenericPlannerRetreatsFromDangerBeforeHealing(t *testing.T) {
	npc := domain.NPCConfig{ID: "N01", Name: "测试角色", Location: "L05", Injury: 2, Resources: map[string]int{"combat": 4}}
	state, err := New(plannerBundle(t, npc, 3)).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if got := state.NPCs[npc.ID].Location; got != "L01" {
		t.Fatalf("location = %s, want nearest deterministic safe location L01", got)
	}
	if got := state.NPCs[npc.ID].Injury; got != 2 {
		t.Fatalf("injury = %d, retreat should happen before healing", got)
	}
}

func assertGeneratedAction(t *testing.T, state *domain.WorldState, actionID string) {
	t.Helper()
	for _, event := range state.Events {
		if event.Type == "action" && event.ActionID == actionID {
			for _, decision := range state.Decisions {
				if len(decision.Choices) > 0 && decision.Choices[0].ActionID == actionID && decision.Choices[0].Generated {
					return
				}
			}
		}
	}
	t.Fatalf("generated action %s and its decision audit record were not found", actionID)
}

package engine

import (
	"context"
	"errors"
	"strings"
	"testing"

	"fantu/internal/director"
	"fantu/internal/domain"
)

type testWorldSelector struct {
	selection director.Selection
	err       error
	calls     int
}

func (s *testWorldSelector) SelectWorldDirective(context.Context, director.SelectionRequest) (director.Selection, error) {
	s.calls++
	return s.selection, s.err
}

func TestWorldDirectorAppliesBeforeNPCDecision(t *testing.T) {
	npc := domain.NPCConfig{
		ID: "N01", Name: "测试角色", Location: "L01", Resources: map[string]int{"combat": 1},
		Strategies: []domain.Strategy{{
			ID: "respond-to-director", ActionID: "cultivate", Description: "响应世界局势",
			FromDay: 1, UntilDay: 1, Duration: 1, Once: true,
			Conditions: []domain.Condition{{Type: "flag", Scope: "world", Key: "director_open"}},
			Effects:    []domain.Effect{{Type: "adjust_resource", Key: "combat", Amount: 1}},
		}},
	}
	bundle := plannerBundle(t, npc, 1)
	bundle.Scenario.Directives = []domain.WorldDirectiveDefinition{{
		ID: "open", Description: "世界局势发生变化", Trigger: "phase_entered", Phase: "测试", Priority: 10, MaxUses: 1,
		Effects: []domain.Effect{{Type: "set_flag", Scope: "world", TargetID: "world", Key: "director_open", Value: "true"}},
	}}
	state, err := New(bundle).Run()
	if err != nil {
		t.Fatal(err)
	}
	if !state.WorldFlag("director_open") || state.NPCs[npc.ID].Resources["combat"] != 2 {
		t.Fatalf("director did not affect the shared NPC snapshot: %+v", state)
	}
	if len(state.DirectorDecisions) != 1 || state.DirectorDecisions[0].DirectiveID != "open" || state.DirectorDecisions[0].Source != "deterministic" {
		t.Fatalf("director audit = %+v", state.DirectorDecisions)
	}
	if len(state.Events) < 2 || state.Events[0].Type != "director" || state.Events[1].StrategyID != "respond-to-director" {
		t.Fatalf("event order = %+v", state.Events)
	}
}

func TestAIWorldDirectorSelectsOnlyCandidateAndAuditsReason(t *testing.T) {
	bundle := plannerBundle(t, domain.NPCConfig{ID: "N01", Name: "测试角色", Location: "L01", Resources: map[string]int{}}, 1)
	bundle.Scenario.Directives = []domain.WorldDirectiveDefinition{
		{ID: "first", Description: "第一项", Trigger: "phase_entered", Phase: "测试", Priority: 10, Effects: []domain.Effect{{Type: "set_flag", Scope: "world", TargetID: "world", Key: "first", Value: "true"}}},
		{ID: "second", Description: "第二项", Trigger: "phase_entered", Phase: "测试", Priority: 5, Effects: []domain.Effect{{Type: "set_flag", Scope: "world", TargetID: "world", Key: "second", Value: "true"}}},
	}
	selector := &testWorldSelector{selection: director.Selection{DirectiveID: "second", Reason: "测试节奏", FocusSignals: []string{"进入阶段"}, Source: "anthropic"}}
	simulation := New(bundle)
	simulation.SetWorldDirector(selector)
	state, err := simulation.Run()
	if err != nil {
		t.Fatal(err)
	}
	if selector.calls != 1 || !state.WorldFlag("second") || state.WorldFlag("first") {
		t.Fatalf("AI selection was not authoritative: %+v", state.WorldFlags)
	}
	decision := state.DirectorDecisions[0]
	if decision.Source != "anthropic" || decision.Reason != "测试节奏" || decision.DirectiveID != "second" {
		t.Fatalf("audit = %+v", decision)
	}
}

func TestAIWorldDirectorFailureRollsBackWithoutDeterministicFallback(t *testing.T) {
	bundle := plannerBundle(t, domain.NPCConfig{ID: "N01", Name: "测试角色", Location: "L01", Resources: map[string]int{}}, 1)
	bundle.Scenario.Directives = []domain.WorldDirectiveDefinition{{ID: "candidate", Description: "候选", Trigger: "phase_entered", Phase: "测试", Priority: 10, Effects: []domain.Effect{{Type: "set_flag", Scope: "world", TargetID: "world", Key: "chosen", Value: "true"}}}}
	simulation := New(bundle)
	simulation.SetWorldDirector(&testWorldSelector{err: errors.New("empty response")})
	if _, err := simulation.Step(nil); err == nil || !strings.Contains(err.Error(), "empty response") {
		t.Fatalf("Step() error = %v", err)
	}
	state := simulation.State()
	if state.Day != 0 || state.WorldFlag("chosen") || len(state.DirectorDecisions) != 0 {
		t.Fatalf("failed model call leaked or fell back: %+v", state)
	}
}

func TestWorldDirectorReplayDoesNotCallSelector(t *testing.T) {
	bundle := plannerBundle(t, domain.NPCConfig{ID: "N01", Name: "测试角色", Location: "L01", Resources: map[string]int{}}, 1)
	bundle.Scenario.Directives = []domain.WorldDirectiveDefinition{{ID: "candidate", Description: "候选", Trigger: "phase_entered", Phase: "测试", Priority: 10, Effects: []domain.Effect{{Type: "set_flag", Scope: "world", TargetID: "world", Key: "chosen", Value: "true"}}}}
	selector := &testWorldSelector{err: errors.New("must not be called")}
	simulation := New(bundle)
	simulation.SetWorldDirector(selector)
	simulation.SetDirectorReplay([]domain.DirectorDecision{{Day: 1, DirectiveID: "candidate", Source: "anthropic", Reason: "saved"}})
	state, err := simulation.Run()
	if err != nil {
		t.Fatal(err)
	}
	if selector.calls != 0 || state.DirectorDecisions[0].Reason != "saved" {
		t.Fatalf("replay called model or lost record: %+v", state.DirectorDecisions)
	}
}

func TestWorldDirectorFailureRollsBackWholeDay(t *testing.T) {
	bundle := plannerBundle(t, domain.NPCConfig{ID: "N01", Name: "测试角色", Location: "L01", Resources: map[string]int{}}, 1)
	bundle.Scenario.Directives = []domain.WorldDirectiveDefinition{{
		ID: "invalid", Description: "非法目标", Trigger: "phase_entered", Phase: "测试", Priority: 10,
		Effects: []domain.Effect{{Type: "set_flag", Scope: "actor", TargetID: "missing", Key: "bad", Value: "true"}},
	}}
	simulation := New(bundle)
	if _, err := simulation.Step(nil); err == nil || !strings.Contains(err.Error(), "unknown actor") {
		t.Fatalf("Step() error = %v", err)
	}
	state := simulation.State()
	if state.Day != 0 || len(state.Events) != 0 || len(state.DirectorDecisions) != 0 || state.Director.Uses["invalid"] != 0 {
		t.Fatalf("failed directive leaked state: %+v", state)
	}
}

package engine

import (
	"reflect"
	"testing"

	"narra/internal/domain"
)

func TestMultiDayActionRevalidatesConditionsOnCompletion(t *testing.T) {
	npc := domain.NPCConfig{
		ID: "N01", Name: "测试角色", Location: "L01", Resources: map[string]int{"combat": 5, "spirit_stones": 10},
		Strategies: []domain.Strategy{{
			ID: "delayed", ActionID: "inquire", Description: "持续调查", FromDay: 1, UntilDay: 2, Duration: 2, Once: true,
			Conditions: []domain.Condition{{Type: "flag", Key: "permit"}},
			Costs:      map[string]int{"spirit_stones": 10},
			Effects:    []domain.Effect{{Type: "set_flag", TargetID: "world", Key: "investigation_done", Value: "true"}},
		}},
	}
	bundle := plannerBundle(t, npc, 2)
	bundle.Scenario.FixedEvents = []domain.FixedEvent{{
		ID: "revoke", Day: 2, Timing: "start", Description: "许可被撤销",
		Effects: []domain.Effect{{Type: "set_flag", TargetID: "world", Key: "permit", Value: "false"}},
	}}
	simulation := New(bundle)
	simulation.state.SetWorldFlag("permit", true)
	state, err := simulation.Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if state.WorldFlag("investigation_done") {
		t.Fatal("action effects committed after completion conditions became false")
	}
	if state.NPCs[npc.ID].Pending != nil {
		t.Fatal("failed action remained pending")
	}
	if got := state.NPCs[npc.ID].Resources["spirit_stones"]; got != 10 {
		t.Fatalf("failed action refund = %d, want 10", got)
	}
	for _, event := range state.Events {
		if event.Type == "action_failed" && event.ActionID == "inquire" {
			return
		}
	}
	t.Fatal("completion failure did not produce an action_failed event")
}

func TestInterruptClearsPendingActionAndRecordsCause(t *testing.T) {
	npc := domain.NPCConfig{
		ID: "N01", Name: "测试角色", Location: "L01", Resources: map[string]int{"combat": 5, "spirit_stones": 10},
		Strategies: []domain.Strategy{{
			ID: "long-work", ActionID: "heal", Description: "长期行动", FromDay: 1, UntilDay: 3, Duration: 3, Once: true,
			Conditions: []domain.Condition{{Type: "flag", Key: "continue_work"}},
			Costs:      map[string]int{"spirit_stones": 10},
			Effects:    []domain.Effect{{Type: "set_flag", TargetID: "world", Key: "work_done", Value: "true"}},
		}},
	}
	simulation := New(plannerBundle(t, npc, 3))
	simulation.state.SetWorldFlag("continue_work", true)
	day1, err := simulation.Step(nil)
	if err != nil || day1.NPCs[npc.ID].Pending == nil {
		t.Fatalf("action did not start: state=%#v err=%v", day1.NPCs[npc.ID].Pending, err)
	}
	if got := day1.NPCs[npc.ID].Resources["spirit_stones"]; got != 0 {
		t.Fatalf("reserved cost left %d stones, want 0", got)
	}
	interrupted, err := simulation.Interrupt(npc.ID, "遭到伏击")
	if err != nil {
		t.Fatalf("Interrupt() error = %v", err)
	}
	if interrupted.NPCs[npc.ID].Pending != nil {
		t.Fatal("interrupted action remained pending")
	}
	if got := interrupted.NPCs[npc.ID].Resources["spirit_stones"]; got != 10 {
		t.Fatalf("interrupt refund = %d, want 10", got)
	}
	last := interrupted.Events[len(interrupted.Events)-1]
	if last.Type != "action_interrupted" || last.ActionID != "heal" || last.StrategyID != "long-work" || last.IntentID != "intent-01-N01" || last.ParentEventID == "" {
		t.Fatalf("interruption event = %#v", last)
	}
	simulation.state.SetWorldFlag("continue_work", false)
	state, err := simulation.Run()
	if err != nil {
		t.Fatalf("continue after interrupt: %v", err)
	}
	if state.WorldFlag("work_done") {
		t.Fatal("interrupted action effects were committed")
	}
}

func TestSuccessfulActionConsumesReservedCostAndReportsFlow(t *testing.T) {
	npc := domain.NPCConfig{
		ID: "N01", Name: "测试角色", Location: "L01", Resources: map[string]int{"combat": 5, "spirit_stones": 10},
		Strategies: []domain.Strategy{{
			ID: "paid", ActionID: "inquire", Description: "付费调查", FromDay: 1, UntilDay: 1, Once: true,
			Costs: map[string]int{"spirit_stones": 10}, Effects: []domain.Effect{{Type: "set_flag", TargetID: "world", Key: "paid_done", Value: "true"}},
		}},
	}
	state, err := New(plannerBundle(t, npc, 1)).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if got := state.NPCs[npc.ID].Resources["spirit_stones"]; got != 0 {
		t.Fatalf("successful cost left %d stones, want 0", got)
	}
	for _, event := range state.Events {
		if event.Type != "action" || event.ActionID != "inquire" {
			continue
		}
		if event.StrategyID != "paid" || event.IntentID == "" {
			t.Fatalf("successful action lacks stable causal IDs: %#v", event)
		}
		for _, effect := range event.Effects {
			if effect.Type == "adjust_resource" && effect.Key == "spirit_stones" && effect.Amount == -10 {
				return
			}
		}
	}
	t.Fatal("successful action did not report its reserved cost")
}

func TestInsufficientExplicitCostRejectsPlayerCommandAtomically(t *testing.T) {
	bundle := loadBlackwind(t)
	player := domain.PlayerConfig{ID: "P00", Name: "玩家", Location: "L01", Resources: map[string]int{"spirit_stones": 5}}
	simulation := NewWithPlayer(bundle, player)
	command := domain.PlayerCommand{ID: "too-expensive", Day: 1, ActionID: "inquire", Costs: map[string]int{"spirit_stones": 10}}
	if _, err := simulation.Step([]domain.PlayerCommand{command}); err == nil {
		t.Fatal("unaffordable command should fail")
	}
	state := simulation.State()
	if state.Day != 0 || state.Player.Resources["spirit_stones"] != 5 || state.Player.Pending != nil {
		t.Fatalf("unaffordable command was not atomic: day=%d resources=%v pending=%#v", state.Day, state.Player.Resources, state.Player.Pending)
	}
}

func TestInterruptFailureDoesNotMutateState(t *testing.T) {
	bundle := loadBlackwind(t)
	simulation := New(bundle)
	before := simulation.State()
	if _, err := simulation.Interrupt("N01", "too early"); err == nil {
		t.Fatal("interrupting idle actor should fail")
	}
	if after := simulation.State(); !reflect.DeepEqual(before, after) {
		t.Fatal("failed interruption mutated world state")
	}
}

func TestRuntimeMovementRejectsMissingRouteAndRequiredItem(t *testing.T) {
	bundle := loadBlackwind(t)
	player := domain.PlayerConfig{ID: "P00", Name: "玩家", Location: "L01", Resources: map[string]int{"combat": 1}}

	noRoute := NewWithPlayer(bundle, player)
	command := domain.PlayerCommand{
		ID: "jump", Day: 1, ActionID: "explore", Description: "直接跳入内谷",
		Conditions: []domain.Condition{{Type: "location", Value: "L01"}},
		Effects:    []domain.Effect{{Type: "move", TargetID: "P00", Value: "L05", BypassRouteFlag: true}},
	}
	if _, err := noRoute.Step([]domain.PlayerCommand{command}); err == nil {
		t.Fatal("movement without a direct route should fail")
	}
	if noRoute.State().Day != 0 {
		t.Fatal("illegal movement did not roll back the day")
	}

	missingItem := NewWithPlayer(bundle, player)
	missingItem.state.SetWorldFlag("valley_open", true)
	command.ID = "unprotected-entry"
	command.Effects[0].Value = "L04"
	command.Effects[0].BypassRouteFlag = false
	if _, err := missingItem.Step([]domain.PlayerCommand{command}); err == nil {
		t.Fatal("movement without required antidote should fail")
	}
	if missingItem.State().Day != 0 {
		t.Fatal("missing-item movement did not roll back the day")
	}
}

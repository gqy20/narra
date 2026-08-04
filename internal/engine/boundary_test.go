package engine

import (
	"testing"

	"narra/internal/domain"
)

func boundaryBundle(t *testing.T, duration, actionDuration, fromDay, untilDay int) domain.Bundle {
	t.Helper()
	npc := domain.NPCConfig{
		ID: "N01", Name: "边界角色", Location: "L01", Resources: map[string]int{},
		Strategies: []domain.Strategy{{
			ID: "boundary", ActionID: "inquire", Description: "边界行动", FromDay: fromDay, UntilDay: untilDay,
			Duration: actionDuration, Once: true, Score: domain.ScoreInput{Goal: 5},
			Effects: []domain.Effect{{Type: "set_flag", Key: "boundary_done", Value: "true"}},
		}},
	}
	return plannerBundle(t, npc, duration)
}

func TestActionCompletesExactlyOnScenarioLastDay(t *testing.T) {
	state, err := New(boundaryBundle(t, 2, 2, 1, 1)).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if !state.ActorFlag("N01", "boundary_done") || state.NPCs["N01"].Pending != nil {
		t.Fatal("action completing exactly on last day did not settle")
	}
}

func TestActionOneDayTooLateIsNotStarted(t *testing.T) {
	state, err := New(boundaryBundle(t, 1, 2, 1, 1)).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if state.ActorFlag("N01", "boundary_done") || state.NPCs["N01"].Pending != nil || len(state.Decisions) != 0 {
		t.Fatal("action extending beyond scenario horizon was started")
	}
}

func TestStrategyCanStartOnWindowLastDayAndFinishLater(t *testing.T) {
	state, err := New(boundaryBundle(t, 2, 2, 1, 1)).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if !state.ActorFlag("N01", "boundary_done") {
		t.Fatal("strategy starting on its window end was incorrectly rejected")
	}
	for _, event := range state.Events {
		if event.Type == "action_start" && event.Day == 1 {
			return
		}
	}
	t.Fatal("window-end start event missing")
}

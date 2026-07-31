package engine

import (
	"testing"

	"fantu/internal/domain"
)

func TestWorldAndActorFlagsDoNotCollide(t *testing.T) {
	state := &domain.WorldState{WorldFlags: map[string]bool{}, ActorFlags: map[string]map[string]bool{}}
	state.SetWorldFlag("prepared", true)
	state.SetActorFlag("N01", "prepared", false)
	state.SetActorFlag("N02", "prepared", true)

	world := domain.Condition{Type: "flag", Key: "prepared", Scope: "world"}
	actor := domain.Condition{Type: "flag", Key: "prepared", Scope: "actor"}
	if !conditionFlag(state, "N01", world) {
		t.Fatal("world flag was not visible in world scope")
	}
	if conditionFlag(state, "N01", actor) {
		t.Fatal("N01 actor flag collided with world flag")
	}
	if !conditionFlag(state, "N02", actor) {
		t.Fatal("N02 actor flag was not visible in actor scope")
	}
}

func TestDefaultSetFlagWritesActorScope(t *testing.T) {
	npc := domain.NPCConfig{
		ID: "N01", Name: "测试角色", Location: "L01", Resources: map[string]int{"combat": 5},
		Strategies: []domain.Strategy{{
			ID: "prepare", ActionID: "inquire", Description: "准备", FromDay: 1, UntilDay: 1, Once: true,
			Effects: []domain.Effect{{Type: "set_flag", Key: "prepared", Value: "true"}},
		}},
	}
	state, err := New(plannerBundle(t, npc, 1)).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if !state.ActorFlag("N01", "prepared") || state.WorldFlag("prepared") {
		t.Fatalf("flag scopes are incorrect: world=%v actor=%v", state.WorldFlag("prepared"), state.ActorFlag("N01", "prepared"))
	}
}

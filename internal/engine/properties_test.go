package engine

import (
	"fmt"
	"testing"

	"narra/internal/domain"
)

func TestStateInvariantMutationMatrix(t *testing.T) {
	bundle := loadBlackwind(t)
	tests := []struct {
		name   string
		mutate func(*domain.WorldState)
	}{
		{"negative resource", func(state *domain.WorldState) { state.NPCs["N01"].Resources["combat"] = -1 }},
		{"duplicate unique item", func(state *domain.WorldState) { state.NPCs["N01"].Items["jade_box"] = 1 }},
		{"unknown location", func(state *domain.WorldState) { state.NPCs["N01"].Location = "missing" }},
		{"relation out of range", func(state *domain.WorldState) {
			state.Relations[domain.RelationKey("N01", "N02")] = domain.Relation{From: "N01", To: "N02", Trust: 6}
		}},
		{"negative market stock", func(state *domain.WorldState) { state.Markets["M01"].Stock["antidote"] = -1 }},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			state := New(bundle).State()
			test.mutate(state)
			if err := ValidateState(state, bundle); err == nil {
				t.Fatal("ValidateState() accepted broken invariant")
			}
		})
	}
}

func TestDuplicateSameActorIntentIsRejected(t *testing.T) {
	simulation := New(loadBlackwind(t))
	action := simulation.bundle.Actions["inquire"]
	intent := domain.ActionIntent{ID: "I1", ActorID: "N01", Action: action, Strategy: domain.Strategy{ID: "S1", ActionID: action.ID}}
	other := intent
	other.ID, other.Strategy.ID = "I2", "S2"
	if err := simulation.startIntents([]domain.ActionIntent{intent, other}); err == nil {
		t.Fatal("startIntents() accepted two same-day actions for one actor")
	}
}

func FuzzClampRelationAlwaysStaysWithinBounds(f *testing.F) {
	for _, seed := range []int{-1000, -6, -5, 0, 5, 6, 1000} {
		f.Add(seed)
	}
	f.Fuzz(func(t *testing.T, value int) {
		got := clampRelation(value)
		if got < -5 || got > 5 {
			t.Fatalf("clampRelation(%d) = %d", value, got)
		}
	})
}

func FuzzValidateRejectsNegativeResources(f *testing.F) {
	f.Add(uint8(1))
	f.Add(uint8(255))
	f.Fuzz(func(t *testing.T, magnitude uint8) {
		if magnitude == 0 {
			magnitude = 1
		}
		bundle := loadBlackwind(t)
		state := New(bundle).State()
		state.NPCs["N01"].Resources["fuzz"] = -int(magnitude)
		if err := ValidateState(state, bundle); err == nil {
			t.Fatal(fmt.Sprintf("accepted negative resource -%d", magnitude))
		}
	})
}

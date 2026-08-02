package director

import (
	"reflect"
	"testing"

	"fantu/internal/domain"
)

func TestChooseUsesPriorityAndStableIDWithoutMutatingState(t *testing.T) {
	state := &domain.WorldState{
		Day: 3, Phase: "萌芽",
		Director: domain.WorldDirectorState{Uses: map[string]int{}, LastUsedDay: map[string]int{}},
	}
	before := cloneDirectorTestState(state)
	definitions := []domain.WorldDirectiveDefinition{
		{ID: "b", Trigger: "quiet_days", MinQuietDays: 3, Priority: 10},
		{ID: "a", Trigger: "quiet_days", MinQuietDays: 3, Priority: 10},
	}
	choice := Choose(state, definitions)
	if choice == nil || choice.Definition.ID != "a" || choice.Score != 13 {
		t.Fatalf("choice = %+v", choice)
	}
	if !reflect.DeepEqual(state, before) {
		t.Fatal("Choose mutated the world snapshot")
	}
}

func TestChooseRespectsUseLimitAndCooldown(t *testing.T) {
	definition := domain.WorldDirectiveDefinition{
		ID: "pressure", Trigger: "actors_at_location_at_least", TargetID: "L01",
		MinValue: 1, Priority: 20, CooldownDays: 2, MaxUses: 2,
	}
	state := &domain.WorldState{
		Day: 4, NPCs: map[string]*domain.NPCState{"N01": {Location: "L01"}},
		Director: domain.WorldDirectorState{Uses: map[string]int{"pressure": 1}, LastUsedDay: map[string]int{"pressure": 3}},
	}
	if choice := Choose(state, []domain.WorldDirectiveDefinition{definition}); choice != nil {
		t.Fatalf("cooldown unexpectedly allowed choice: %+v", choice)
	}
	state.Day = 6
	if choice := Choose(state, []domain.WorldDirectiveDefinition{definition}); choice == nil {
		t.Fatal("expired cooldown did not allow choice")
	}
	state.Director.Uses[definition.ID] = 2
	if choice := Choose(state, []domain.WorldDirectiveDefinition{definition}); choice != nil {
		t.Fatalf("max uses unexpectedly allowed choice: %+v", choice)
	}
}

func TestChooseDetectsMarketAndPhaseSignals(t *testing.T) {
	state := &domain.WorldState{
		Day: 5, Phase: "扩散", Markets: map[string]*domain.MarketState{
			"M01": {ID: "M01", Stock: map[string]int{"antidote": 2}},
		},
		Director: domain.WorldDirectorState{LastPhase: "萌芽", Uses: map[string]int{}, LastUsedDay: map[string]int{}},
	}
	choice := Choose(state, []domain.WorldDirectiveDefinition{
		{ID: "phase", Trigger: "phase_entered", Phase: "扩散", Priority: 10},
		{ID: "market", Trigger: "market_stock_at_most", TargetID: "M01", Key: "antidote", MinValue: 3, Priority: 20},
	})
	if choice == nil || choice.Definition.ID != "market" || len(choice.Signals) != 1 || choice.Signals[0].Value != 2 {
		t.Fatalf("choice = %+v", choice)
	}
}

func cloneDirectorTestState(source *domain.WorldState) *domain.WorldState {
	clone := *source
	clone.Director.Uses = make(map[string]int, len(source.Director.Uses))
	for key, value := range source.Director.Uses {
		clone.Director.Uses[key] = value
	}
	clone.Director.LastUsedDay = make(map[string]int, len(source.Director.LastUsedDay))
	for key, value := range source.Director.LastUsedDay {
		clone.Director.LastUsedDay[key] = value
	}
	return &clone
}

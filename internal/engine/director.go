package engine

import (
	"fmt"

	"fantu/internal/director"
	"fantu/internal/domain"
)

// runWorldDirector lets the director select one scenario-authored capability
// before NPCs inspect the day's shared snapshot. Effects still flow through
// the engine's normal validation, provenance, and transactional rollback.
func (e *Engine) runWorldDirector() error {
	choice := director.Choose(e.state, e.bundle.Scenario.Directives)
	e.state.Director.LastPhase = e.state.Phase
	if choice == nil {
		return nil
	}

	definition := choice.Definition
	event := e.newEvent("director", "world", definition.TargetID, definition.Description, definition.ID, definition.Effects)
	if err := e.applyEffects(event, definition.Effects, "world"); err != nil {
		return fmt.Errorf("world directive %s: %w", definition.ID, err)
	}
	e.state.Events = append(e.state.Events, event)
	e.state.Director.LastDirectiveDay = e.state.Day
	e.state.Director.Uses[definition.ID]++
	e.state.Director.LastUsedDay[definition.ID] = e.state.Day
	e.state.DirectorDecisions = append(e.state.DirectorDecisions, domain.DirectorDecision{
		Day: e.state.Day, DirectiveID: definition.ID, Trigger: definition.Trigger,
		Description: definition.Description, Score: choice.Score, Source: director.DeterministicSource,
		Signals: append([]domain.WorldSignal(nil), choice.Signals...), EventID: event.ID,
	})
	return nil
}

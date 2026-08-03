package engine

import (
	"context"
	"fmt"

	"fantu/internal/director"
	"fantu/internal/domain"
)

// runWorldDirector lets the director select one scenario-authored capability
// before NPCs inspect the day's shared snapshot. Effects still flow through
// the engine's normal validation, provenance, and transactional rollback.
func (e *Engine) runWorldDirector() error {
	request := director.Request(e.state, e.bundle.Scenario.Directives)
	choices := director.Choices(e.state, e.bundle.Scenario.Directives)
	e.state.Director.LastPhase = e.state.Phase
	if len(request.Candidates) == 0 {
		return nil
	}
	selectedID, source, reason := choices[0].Definition.ID, director.DeterministicSource, ""
	var focusSignals []string
	if e.replayingDirector {
		recorded, ok := e.directorReplay[e.state.Day]
		if !ok {
			return fmt.Errorf("world director replay is missing day %d decision", e.state.Day)
		}
		selectedID, source, reason = recorded.DirectiveID, recorded.Source, recorded.Reason
		focusSignals = append([]string(nil), recorded.FocusSignals...)
	} else if e.directorSelector != nil {
		selection, err := e.directorSelector.SelectWorldDirective(context.Background(), request)
		if err != nil {
			return fmt.Errorf("world director model selection: %w", err)
		}
		selectedID, source, reason = selection.DirectiveID, selection.Source, selection.Reason
		focusSignals = append([]string(nil), selection.FocusSignals...)
		if selectedID == "" {
			return fmt.Errorf("world director model returned an empty directive_id")
		}
	}
	var choice *director.Choice
	for index := range choices {
		if choices[index].Definition.ID == selectedID {
			copy := choices[index]
			choice = &copy
			break
		}
	}
	if choice == nil {
		return fmt.Errorf("world director selected unavailable directive %q", selectedID)
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
		Description: definition.Description, Score: choice.Score,
		Reason: reason, FocusSignals: focusSignals, Source: source,
		Signals: append([]domain.WorldSignal(nil), choice.Signals...), EventID: event.ID,
	})
	return nil
}

// Package director selects bounded, scenario-authored world directives.
// It never mutates WorldState and never constructs arbitrary effects.
package director

import (
	"context"
	"fmt"
	"sort"

	"fantu/internal/domain"
)

const DeterministicSource = "deterministic"

type SelectionRequest struct {
	ScenarioID string      `json:"scenario_id"`
	Day        int         `json:"day"`
	Phase      string      `json:"phase"`
	Candidates []Candidate `json:"candidates"`
}

type Candidate struct {
	DirectiveID string               `json:"directive_id"`
	Description string               `json:"description"`
	Score       int                  `json:"deterministic_score"`
	Signals     []domain.WorldSignal `json:"signals"`
}

type Selection struct {
	DirectiveID  string   `json:"directive_id"`
	Reason       string   `json:"reason"`
	FocusSignals []string `json:"focus_signals"`
	Source       string   `json:"source"`
}

type Selector interface {
	SelectWorldDirective(context.Context, SelectionRequest) (Selection, error)
}

type Choice struct {
	Definition domain.WorldDirectiveDefinition
	Score      int
	Signals    []domain.WorldSignal
}

// Choose returns at most one legal directive for the current day. Stable
// sorting makes identical snapshots produce identical choices.
func Choose(state *domain.WorldState, definitions []domain.WorldDirectiveDefinition) *Choice {
	choices := Choices(state, definitions)
	if len(choices) == 0 {
		return nil
	}
	choice := choices[0]
	return &choice
}

// Choices returns every currently legal candidate in stable score order.
func Choices(state *domain.WorldState, definitions []domain.WorldDirectiveDefinition) []Choice {
	choices := make([]Choice, 0, len(definitions))
	for _, definition := range definitions {
		if !available(state, definition) || supersededResourceThreshold(state, definition, definitions) {
			continue
		}
		signals, urgency, ok := matchTrigger(state, definition)
		if !ok {
			continue
		}
		choices = append(choices, Choice{
			Definition: definition,
			Score:      definition.Priority + urgency,
			Signals:    signals,
		})
	}
	sort.SliceStable(choices, func(i, j int) bool {
		if choices[i].Score != choices[j].Score {
			return choices[i].Score > choices[j].Score
		}
		return choices[i].Definition.ID < choices[j].Definition.ID
	})
	return choices
}

func Request(state *domain.WorldState, definitions []domain.WorldDirectiveDefinition) SelectionRequest {
	choices := Choices(state, definitions)
	request := SelectionRequest{ScenarioID: state.RunID, Day: state.Day, Phase: state.Phase, Candidates: make([]Candidate, 0, len(choices))}
	for _, choice := range choices {
		request.Candidates = append(request.Candidates, Candidate{DirectiveID: choice.Definition.ID, Description: choice.Definition.Description, Score: choice.Score, Signals: append([]domain.WorldSignal(nil), choice.Signals...)})
	}
	return request
}

func supersededResourceThreshold(state *domain.WorldState, definition domain.WorldDirectiveDefinition, definitions []domain.WorldDirectiveDefinition) bool {
	if definition.Trigger != "player_resource_at_least" {
		return false
	}
	for _, candidate := range definitions {
		if candidate.Trigger == definition.Trigger && candidate.Key == definition.Key && candidate.MinValue > definition.MinValue && state.Director.Uses[candidate.ID] > 0 {
			return true
		}
	}
	return false
}

func available(state *domain.WorldState, definition domain.WorldDirectiveDefinition) bool {
	if definition.FromDay > 0 && state.Day < definition.FromDay {
		return false
	}
	if definition.UntilDay > 0 && state.Day > definition.UntilDay {
		return false
	}
	if definition.Phase != "" && definition.Phase != state.Phase {
		return false
	}
	uses := state.Director.Uses[definition.ID]
	if definition.MaxUses > 0 && uses >= definition.MaxUses {
		return false
	}
	if lastDay, used := state.Director.LastUsedDay[definition.ID]; used && definition.CooldownDays > 0 && state.Day-lastDay <= definition.CooldownDays {
		return false
	}
	return true
}

func matchTrigger(state *domain.WorldState, definition domain.WorldDirectiveDefinition) ([]domain.WorldSignal, int, bool) {
	switch definition.Trigger {
	case "phase_entered":
		if state.Phase == "" || state.Phase == state.Director.LastPhase {
			return nil, 0, false
		}
		return []domain.WorldSignal{{Type: definition.Trigger, SubjectID: state.Phase, Value: state.Day, Description: "局势进入" + state.Phase}}, 1, true
	case "quiet_days":
		quietDays := state.Day - latestPublicWorldEventDay(state)
		if quietDays < definition.MinQuietDays {
			return nil, 0, false
		}
		return []domain.WorldSignal{{Type: definition.Trigger, SubjectID: "world", Value: quietDays, Description: fmt.Sprintf("公开局势已沉寂%d天", quietDays)}}, quietDays, true
	case "market_stock_at_most":
		market := state.Markets[definition.TargetID]
		if market == nil || market.Stock[definition.Key] > definition.MinValue {
			return nil, 0, false
		}
		stock := market.Stock[definition.Key]
		return []domain.WorldSignal{{Type: definition.Trigger, SubjectID: definition.TargetID, Value: stock, Description: fmt.Sprintf("%s库存降至%d", definition.Key, stock)}}, definition.MinValue - stock, true
	case "actors_at_location_at_least":
		count := 0
		for _, npc := range state.NPCs {
			if npc.Location == definition.TargetID {
				count++
			}
		}
		if state.Player != nil && state.Player.Location == definition.TargetID {
			count++
		}
		if count < definition.MinValue {
			return nil, 0, false
		}
		return []domain.WorldSignal{{Type: definition.Trigger, SubjectID: definition.TargetID, Value: count, Description: fmt.Sprintf("当地聚集%d名行动者", count)}}, count - definition.MinValue, true
	case "player_resource_at_least":
		if state.Player == nil || state.Player.Resources[definition.Key] < definition.MinValue {
			return nil, 0, false
		}
		value := state.Player.Resources[definition.Key]
		return []domain.WorldSignal{{Type: definition.Trigger, SubjectID: state.Player.ID, Value: value, Description: fmt.Sprintf("玩家%s达到%d", definition.Key, value)}}, value - definition.MinValue, true
	default:
		return nil, 0, false
	}
}

func latestPublicWorldEventDay(state *domain.WorldState) int {
	latest := 0
	for _, event := range state.Events {
		if event.ActorID == "world" && event.Type != "director" && event.Day > latest {
			latest = event.Day
		}
	}
	if state.Director.LastDirectiveDay > latest {
		latest = state.Director.LastDirectiveDay
	}
	return latest
}

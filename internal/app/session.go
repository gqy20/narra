package app

import (
	"fmt"
	"sort"

	"fantu/internal/domain"
	"fantu/internal/engine"
)

type Session struct {
	bundle               domain.Bundle
	initial              domain.PlayerConfig
	engine               *engine.Engine
	history              []string
	nextID               int
	lastTurn             *TurnFeedback
	metrics              PlayMetrics
	quietWaitStreak      int
	lastActiveAction     string
	repeatedActiveAction int
}

func NewSession(bundle domain.Bundle, player domain.PlayerConfig) (*Session, error) {
	if err := validatePlayer(bundle, player); err != nil {
		return nil, err
	}
	session := &Session{
		bundle: bundle, initial: clonePlayerConfig(player), engine: engine.NewWithPlayer(bundle, player),
	}
	session.metrics.MaxActionCatalog = len(session.actionCatalog(session.engine.State()))
	return session, nil
}

func validatePlayer(bundle domain.Bundle, player domain.PlayerConfig) error {
	if player.ID == "" || player.Name == "" {
		return fmt.Errorf("player requires id and name")
	}
	if _, ok := bundle.Locations[player.Location]; !ok {
		return fmt.Errorf("player references unknown location %s", player.Location)
	}
	if player.Injury < 0 || player.Injury > 3 {
		return fmt.Errorf("player injury must be between 0 and 3")
	}
	for resource, amount := range player.Resources {
		if resource == "" || amount < 0 {
			return fmt.Errorf("player has invalid resource %q=%d", resource, amount)
		}
	}
	for _, belief := range player.Beliefs {
		if _, ok := bundle.Facts[belief.FactID]; !ok {
			return fmt.Errorf("player references unknown fact %s", belief.FactID)
		}
	}
	return nil
}

func (s *Session) View() PlayerView {
	state := s.engine.State()
	view := PlayerView{
		ScenarioID: s.bundle.Scenario.ID, Title: s.bundle.Scenario.Title,
		Day: state.Day, Duration: s.bundle.Scenario.Duration, Phase: state.Phase,
		Ended: state.Day >= s.bundle.Scenario.Duration, Resolved: state.Outcome != "", Player: s.visiblePlayer(state),
		Location:    s.visibleLocation(state.Player.Location),
		KnownActors: s.visibleActors(state), KnownFacts: visibleBeliefs(state.Player.Beliefs),
		RecentEvents: s.visibleEvents(state),
	}
	if view.Resolved || view.Ended {
		view.Outcome = state.Outcome
		view.Ending = s.endingSummary(state)
	} else {
		view.AvailableActions = s.actionCatalog(state)
		view.Guidance = s.guidance(state, view.AvailableActions)
		view.Travel = s.travelGuidance(state)
	}
	view.LastTurn = cloneTurnFeedback(s.lastTurn)
	view.Metrics = s.metricsView(state)
	return view
}

func (s *Session) Execute(actionID string) (PlayerView, error) {
	return s.execute(actionID, false)
}

func (s *Session) execute(actionID string, allowAfterResolution bool) (PlayerView, error) {
	state := s.engine.State()
	if state.Day >= s.bundle.Scenario.Duration {
		return s.View(), fmt.Errorf("scenario already ended on day %d", state.Day)
	}
	if state.Outcome != "" && !allowAfterResolution {
		return s.View(), fmt.Errorf("core situation already resolved on day %d", state.Day)
	}
	options := s.actionOptions(state)
	s.recordCatalogSize(len(options))
	option, ok := options[actionID]
	if actionID == "wait" {
		option, ok = waitOption("观察局势并推进一天"), true
	}
	if !ok {
		return s.View(), fmt.Errorf("action %q is not currently available", actionID)
	}
	var err error
	actionName := option.view.Name
	var after *domain.WorldState
	if option.advanceMode != "" {
		after, s.lastTurn, err = s.advanceUntilDecision(state, actionID, actionName, option.advanceMode)
	} else if option.command == nil {
		after, err = s.engine.Step(nil)
	} else {
		s.nextID++
		command := *option.command
		command.ID = fmt.Sprintf("interactive-%02d-%03d", state.Day+1, s.nextID)
		command.Day = state.Day + 1
		after, err = s.engine.Step([]domain.PlayerCommand{command})
		if err != nil {
			s.nextID--
		}
	}
	if err != nil {
		return s.View(), err
	}
	s.history = append(s.history, actionID)
	if option.advanceMode == "" {
		s.lastTurn = s.turnFeedback(actionID, actionName, state, after)
	}
	s.recordMetrics(actionID, state, after, s.lastTurn)
	return s.View(), nil
}

func (s *Session) History() []string {
	return append([]string(nil), s.history...)
}

func (s *Session) visiblePlayer(state *domain.WorldState) VisiblePlayer {
	player := state.Player
	view := VisiblePlayer{
		ID: player.ID, Name: player.Name, Injury: player.Injury,
		Resources: copyIntMap(player.Resources), Items: s.visibleItems(player.Items),
	}
	if player.Pending != nil {
		view.Busy = true
		view.BusyUntil = player.Pending.CompleteDay
		view.BusyAction = player.Pending.Intent.Strategy.Description
	}
	return view
}

func (s *Session) visibleItems(items map[string]int) []VisibleItem {
	result := make([]VisibleItem, 0)
	for id, amount := range items {
		if amount <= 0 {
			continue
		}
		name := id
		if definition, ok := s.bundle.Items[id]; ok {
			name = definition.Name
		}
		result = append(result, VisibleItem{ID: id, Name: name, Amount: amount})
	}
	sort.Slice(result, func(i, j int) bool { return result[i].ID < result[j].ID })
	return result
}

func (s *Session) visibleLocation(locationID string) VisibleLocation {
	location := s.bundle.Locations[locationID]
	return VisibleLocation{ID: locationID, Name: location.Name, Safe: location.Safe}
}

func (s *Session) visibleActors(state *domain.WorldState) []VisibleActor {
	actors := make([]VisibleActor, 0)
	for _, npc := range state.NPCs {
		if npc.Location == state.Player.Location {
			actors = append(actors, VisibleActor{ID: npc.ID, Name: npc.Name, Faction: npc.Faction})
		}
	}
	sort.Slice(actors, func(i, j int) bool { return actors[i].ID < actors[j].ID })
	return actors
}

func visibleBeliefs(beliefs map[string]domain.Belief) []VisibleBelief {
	result := make([]VisibleBelief, 0, len(beliefs))
	for _, belief := range beliefs {
		result = append(result, VisibleBelief{
			FactID: belief.FactID, Claim: belief.Claim, Confidence: belief.Confidence,
			Source: belief.Source, LearnedOn: belief.LearnedOn, Contested: belief.Contested,
		})
	}
	sort.Slice(result, func(i, j int) bool { return result[i].FactID < result[j].FactID })
	return result
}

func (s *Session) visibleEvents(state *domain.WorldState) []VisibleEvent {
	result := make([]VisibleEvent, 0, 8)
	for _, event := range state.Events {
		if event.ActorID != "world" && event.ActorID != state.Player.ID && event.TargetID != state.Player.ID {
			continue
		}
		actor := "世界"
		if event.ActorID == state.Player.ID {
			actor = state.Player.Name
		} else if npc, ok := state.NPCs[event.ActorID]; ok {
			actor = npc.Name
		}
		result = append(result, VisibleEvent{Day: event.Day, Type: event.Type, ActorName: actor, Description: event.Description})
	}
	if len(result) > 8 {
		result = result[len(result)-8:]
	}
	return result
}

func clonePlayerConfig(source domain.PlayerConfig) domain.PlayerConfig {
	clone := source
	clone.Resources = copyIntMap(source.Resources)
	clone.Items = append([]string(nil), source.Items...)
	clone.Beliefs = append([]domain.Belief(nil), source.Beliefs...)
	for i := range clone.Beliefs {
		clone.Beliefs[i].Evidence = append([]domain.BeliefEvidence(nil), source.Beliefs[i].Evidence...)
	}
	return clone
}

func copyIntMap(source map[string]int) map[string]int {
	result := make(map[string]int, len(source))
	for key, value := range source {
		result[key] = value
	}
	return result
}

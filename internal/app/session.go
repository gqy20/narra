package app

import (
	"context"
	"fmt"
	"sort"
	"strings"

	"narra/internal/director"
	"narra/internal/domain"
	"narra/internal/engine"
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
	dialogues            []DialogueExchange
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

func (s *Session) SetWorldDirector(selector director.Selector) { s.engine.SetWorldDirector(selector) }

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
		Presentation: s.bundle.Presentation,
		Day:          state.Day, Duration: s.bundle.Scenario.Duration, Phase: state.Phase,
		Ended: state.Day >= s.bundle.Scenario.Duration, Resolved: state.Outcome != "", Player: s.visiblePlayer(state),
		Location:    s.visibleLocation(state.Player.Location),
		KnownActors: s.visibleActors(state), KnownFacts: s.visibleBeliefs(state),
		RecentEvents:     s.visibleEvents(state),
		CausalThreads:    s.visibleInfluence(state, state.Decisions, true),
		AvailableActions: make([]AvailableAction, 0),
	}
	if view.Resolved || view.Ended {
		view.Outcome = visibleOutcome(state.Outcome)
		view.Ending = s.endingSummary(state)
	} else {
		view.AvailableActions = s.actionCatalog(state)
		view.Guidance = s.guidance(state, view.AvailableActions)
		view.Travel = s.travelGuidance(state)
	}
	view.WorldMap = s.visibleWorldMap(state, view.AvailableActions)
	view.LastTurn = cloneTurnFeedback(s.lastTurn)
	view.Metrics = s.metricsView(state)
	view.Preparation = s.preparationSummary(state)
	view.RouteProgresses = s.routeProgresses(state)
	view.KnowledgeGraph = knowledgeGraph(view)
	return view
}

func (s *Session) Execute(actionID string) (PlayerView, error) {
	return s.ExecuteContext(context.Background(), actionID)
}

func (s *Session) ExecuteContext(ctx context.Context, actionID string) (PlayerView, error) {
	return s.executeContext(ctx, actionID, false)
}

func (s *Session) execute(actionID string, allowAfterResolution bool) (PlayerView, error) {
	return s.executeContext(context.Background(), actionID, allowAfterResolution)
}

func (s *Session) executeContext(ctx context.Context, actionID string, allowAfterResolution bool) (PlayerView, error) {
	state := s.engine.State()
	if state.Day >= s.bundle.Scenario.Duration {
		return s.View(), fmt.Errorf("scenario already ended on day %d", state.Day)
	}
	if state.Outcome != "" && !allowAfterResolution {
		return s.View(), fmt.Errorf("core situation already resolved on day %d", state.Day)
	}
	options := s.actionOptions(state)
	option, ok := options[actionID]
	if actorID, found := strings.CutPrefix(actionID, "conversation:"); found {
		option, ok = s.conversationOption(state, actorID)
	}
	if actionID == "wait" {
		option, ok = waitOption("观察局势并推进一天"), true
	}
	if !ok {
		return s.View(), fmt.Errorf("action %q is not currently available", actionID)
	}
	return s.executeOptionContext(ctx, state, actionID, option)
}

func (s *Session) executeOptionContext(ctx context.Context, state *domain.WorldState, actionID string, option actionOption) (PlayerView, error) {
	checkpoint := s.engine.Checkpoint()
	previousNextID := s.nextID
	previousLastTurn := cloneTurnFeedback(s.lastTurn)
	s.recordCatalogSize(len(s.actionOptions(state)))
	var err error
	actionName := option.view.Name
	var after *domain.WorldState
	if option.advanceMode != "" {
		after, s.lastTurn, err = s.advanceUntilDecision(ctx, state, actionID, actionName, option.advanceMode)
	} else if option.command == nil {
		after, err = s.engine.StepContext(ctx, nil)
	} else {
		s.nextID++
		command := *option.command
		command.ID = fmt.Sprintf("interactive-%02d-%03d", state.Day+1, s.nextID)
		command.Day = state.Day + 1
		after, err = s.engine.StepContext(ctx, []domain.PlayerCommand{command})
	}
	if err != nil {
		s.engine.Restore(checkpoint)
		s.nextID = previousNextID
		s.lastTurn = previousLastTurn
		return s.View(), err
	}
	s.history = append(s.history, actionID)
	if option.advanceMode == "" {
		s.lastTurn = s.turnFeedback(actionID, actionName, state, after)
	}
	s.recordMetrics(actionID, state, after, s.lastTurn)
	return s.View(), nil
}

// ConversationDuration exposes the content-authored duration of a successful
// player-to-NPC exchange without adding a synthetic action to PlayerView.
func (s *Session) ConversationDuration() int {
	rule := s.bundle.Rules.Player.Conversation
	if !rule.Enabled {
		return 0
	}
	return s.bundle.Actions[rule.ActionID].Duration
}

// ExecuteConversationContext advances one content-authored social action when
// the player's message does not perform another available action.
func (s *Session) ExecuteConversationContext(ctx context.Context, actorID string) (PlayerView, error) {
	state := s.engine.State()
	if state.Day >= s.bundle.Scenario.Duration {
		return s.View(), fmt.Errorf("scenario already ended on day %d", state.Day)
	}
	if state.Outcome != "" {
		return s.View(), fmt.Errorf("core situation already resolved on day %d", state.Day)
	}
	actionID := "conversation:" + actorID
	option, ok := s.conversationOption(state, actorID)
	if !ok {
		return s.View(), fmt.Errorf("conversation target is not available at the current location")
	}
	return s.executeOptionContext(ctx, state, actionID, option)
}

func (s *Session) conversationOption(state *domain.WorldState, actorID string) (actionOption, bool) {
	npc, ok := state.NPCs[actorID]
	if !ok || npc.Location != state.Player.Location {
		return actionOption{}, false
	}
	rule := s.bundle.Rules.Player.Conversation
	action, ok := s.bundle.Actions[rule.ActionID]
	if !rule.Enabled || !ok || !fitsHorizon(state.Day, action.Duration, s.bundle.Scenario.Duration) {
		return actionOption{}, false
	}
	option := actionOption{
		view: AvailableAction{
			ID: "conversation:" + actorID, Kind: "conversation", Category: "social", Name: action.Name,
			Description: action.Name + "：" + npc.Name, Duration: action.Duration,
			TargetID: actorID, TargetName: npc.Name,
		},
		command: &domain.PlayerCommand{
			ActionID: action.ID, Duration: action.Duration, TargetID: actorID,
			Description: action.Name + "：" + npc.Name,
			Conditions:  []domain.Condition{{Type: "location", Value: state.Player.Location}},
		},
	}
	return option, true
}

func (s *Session) History() []string {
	return append([]string(nil), s.history...)
}

// DirectorDecisions returns a detached audit trail of authoritative world
// director choices made during this session.
func (s *Session) DirectorDecisions() []domain.DirectorDecision {
	state := s.engine.State()
	return state.DirectorDecisions
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
	return VisibleLocation{
		ID: locationID, Name: location.Name, Safe: location.Safe, SceneKey: location.SceneKey,
		Description: location.Description, Atmosphere: location.Atmosphere,
	}
}

func (s *Session) visibleActors(state *domain.WorldState) []VisibleActor {
	actors := make([]VisibleActor, 0)
	plans := make(map[string]VisibleActorPlan)
	for _, plan := range s.visibleActorPlans(state) {
		plans[plan.ID] = plan
	}
	for _, npc := range state.NPCs {
		if npc.Location == state.Player.Location {
			profile := "公开资料尚未收集"
			role := "可交谈人物"
			risk := "公开信息不足，暂时无法判断消息可能被如何使用。"
			focus := make([]string, 0)
			for _, config := range s.bundle.NPCs {
				if config.ID != npc.ID {
					continue
				}
				if config.PublicProfile != "" {
					profile = config.PublicProfile
				}
				if config.PublicRole != "" {
					role = config.PublicRole
				}
				if config.PublicRisk != "" {
					risk = config.PublicRisk
				}
				for _, interest := range config.PublicInterests {
					focus = append(focus, interest.Label)
				}
				break
			}
			visible := VisibleActor{
				ID: npc.ID, Name: npc.Name, Faction: npc.Faction, PublicProfile: profile,
				PublicRole: role, PublicFocus: focus, PublicRisk: risk,
			}
			if plan, ok := plans[npc.ID]; ok {
				copy := plan
				visible.Plan = &copy
			}
			actors = append(actors, visible)
		}
	}
	sort.Slice(actors, func(i, j int) bool { return actors[i].ID < actors[j].ID })
	return actors
}

func (s *Session) visibleBeliefs(state *domain.WorldState) []VisibleBelief {
	result := make([]VisibleBelief, 0, len(state.Player.Beliefs))
	for _, belief := range state.Player.Beliefs {
		result = append(result, VisibleBelief{
			FactID: belief.FactID, Claim: belief.Claim, Confidence: belief.Confidence,
			Source: s.visibleSource(state, belief.Source), LearnedOn: belief.LearnedOn, Contested: belief.Contested,
		})
	}
	sort.Slice(result, func(i, j int) bool { return result[i].FactID < result[j].FactID })
	return result
}

func (s *Session) visibleSource(state *domain.WorldState, source string) string {
	switch source {
	case "player-investigation":
		return s.uiText("source_investigation")
	case "player-investigation-lead":
		return s.uiText("source_investigation_lead")
	case "wandering-broker":
		return s.uiText("source_broker")
	case state.Player.ID:
		return "你"
	}
	if npc, ok := state.NPCs[source]; ok {
		return npc.Name
	}
	if source == "" {
		return s.uiText("source_unknown")
	}
	return source
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

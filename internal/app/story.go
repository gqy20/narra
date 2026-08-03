package app

import (
	"fmt"
	"sort"
	"strings"

	"fantu/internal/domain"
)

func (s *Session) addStoryActions(options map[string]actionOption, state *domain.WorldState) {
	for arcID, arc := range s.bundle.StoryArcs {
		for _, node := range arc.Nodes {
			if node.FactID != "" || state.StoryStates[arcID] != node.FromState || node.FromDay > 0 && state.Day < node.FromDay || node.UntilDay > 0 && state.Day > node.UntilDay || !storyConditionsMet(state, node.Conditions) {
				continue
			}
			action, ok := s.bundle.Actions[node.ActionID]
			if !ok || !fitsHorizon(state.Day, action.Duration, s.bundle.Scenario.Duration) || node.LocationID != "" && state.Player.Location != node.LocationID {
				continue
			}
			target, ok := state.NPCs[node.TargetID]
			if !ok || !node.AllowRemoteTarget && target.Location != state.Player.Location {
				continue
			}
			targetRole := "可交谈人物"
			for _, config := range s.bundle.NPCs {
				if config.ID == node.TargetID {
					if config.PublicRole != "" {
						targetRole = config.PublicRole
					}
					break
				}
			}
			kind := node.Kind
			if kind == "" {
				kind = "route"
			}
			category := node.Category
			if category == "" {
				category = "information"
			}
			for _, choice := range node.Choices {
				if !storyConditionsMet(state, choice.Conditions) {
					continue
				}
				conditions := append([]domain.Condition(nil), node.Conditions...)
				conditions = append(conditions, node.CompletionConditions...)
				if node.LocationID != "" {
					conditions = append(conditions, domain.Condition{Type: "location", Value: node.LocationID})
				}
				conditions = append(conditions, choice.Conditions...)
				effects := materializeStoryEffects(choice.Effects, state.Player.ID, node.TargetID)
				effects = append(effects, domain.Effect{Type: "set_story_state", Key: arcID, Value: choice.ToState})
				commandDescription := choice.CommandDescription
				if commandDescription == "" {
					commandDescription = choice.Description
				}
				options[choice.ID] = actionOption{
					view: AvailableAction{
						ID: choice.ID, Kind: kind, Category: category, Name: choice.Name, Description: choice.Description,
						Duration: action.Duration, TargetID: node.TargetID, TargetName: target.Name, TargetRole: targetRole,
						TermID: choice.TermID, TermLabel: choice.TermLabel, PersonalOutcome: choice.PersonalOutcome,
						Relevance: choice.Relevance, Risk: choice.Risk,
						ExpectedOutcomes: append([]string(nil), choice.ExpectedOutcomes...), Resolves: append([]string(nil), choice.Resolves...),
						Warnings: append([]string(nil), choice.Warnings...), Irreversible: choice.Irreversible,
					},
					command: &domain.PlayerCommand{
						ActionID: action.ID, TargetID: node.TargetID, Description: commandDescription,
						Conditions: conditions, Effects: effects,
					},
				}
			}
		}
	}
}

func (s *Session) addStoryInformationActions(options map[string]actionOption, state *domain.WorldState, actor VisibleActor, belief domain.Belief, action domain.ActionDefinition) bool {
	added := false
	for arcID, arc := range s.bundle.StoryArcs {
		for _, node := range arc.Nodes {
			if state.StoryStates[arcID] != node.FromState || node.ActionID != action.ID || node.TargetID != actor.ID || node.FactID != belief.FactID || belief.Confidence < node.MinConfidence || node.FromDay > 0 && state.Day < node.FromDay || node.UntilDay > 0 && state.Day > node.UntilDay || node.LocationID != "" && state.Player.Location != node.LocationID || !storyConditionsMet(state, node.Conditions) {
				continue
			}
			for _, choice := range node.Choices {
				if !storyConditionsMet(state, choice.Conditions) {
					continue
				}
				relevance, risk := s.publicInformationContext(actor.ID, s.bundle.Facts[node.FactID])
				if choice.Relevance != "" {
					relevance = choice.Relevance
				}
				if choice.Risk != "" {
					risk = choice.Risk
				}
				effects := []domain.Effect{{
					Type: "set_belief", TargetID: actor.ID, FactID: node.FactID, Claim: belief.Claim,
					Confidence: belief.Confidence, EvidenceStrength: belief.EvidenceStrength,
					Source: state.Player.ID, Propagation: "private", Secrecy: belief.Secrecy,
				}}
				effects = append(effects, materializeStoryEffects(choice.Effects, state.Player.ID, actor.ID)...)
				effects = append(effects, domain.Effect{Type: "set_story_state", Key: arcID, Value: choice.ToState})
				conditions := []domain.Condition{{Type: "belief", Key: node.FactID, MinConfidence: node.MinConfidence}, {Type: "location", Value: state.Player.Location}}
				conditions = append(conditions, node.Conditions...)
				conditions = append(conditions, node.CompletionConditions...)
				conditions = append(conditions, choice.Conditions...)
				commandDescription := choice.CommandDescription
				if commandDescription == "" {
					commandDescription = choice.Description
				}
				kind := node.Kind
				if kind == "" {
					kind = "tell"
				}
				category := node.Category
				if category == "" {
					category = "information"
				}
				options[choice.ID] = actionOption{
					view: AvailableAction{
						ID: choice.ID, Kind: kind, Category: category, Name: choice.Name, Description: choice.Description,
						Duration: action.Duration, TargetID: actor.ID, TargetName: actor.Name, TargetRole: actor.PublicRole,
						FactID: node.FactID, FactClaim: belief.Claim, TermID: choice.TermID, TermLabel: choice.TermLabel,
						PersonalOutcome: choice.PersonalOutcome, Relevance: relevance, Risk: risk,
						ExpectedOutcomes: append([]string(nil), choice.ExpectedOutcomes...), Resolves: append([]string(nil), choice.Resolves...), Warnings: append([]string(nil), choice.Warnings...),
						Irreversible: choice.Irreversible,
					},
					command: &domain.PlayerCommand{
						ActionID: action.ID, TargetID: actor.ID, Description: commandDescription,
						Conditions: conditions, Effects: effects,
					},
				}
				added = true
			}
		}
	}
	return added
}

func (s *Session) storyRouteProgress(state *domain.WorldState) *RouteProgress {
	var selected *domain.StoryProgressRule
	selectedArcID := ""
	for arcID, arc := range s.bundle.StoryArcs {
		for index := range arc.ProgressRules {
			rule := &arc.ProgressRules[index]
			if rule.FromDay > 0 && state.Day < rule.FromDay || rule.UntilDay > 0 && state.Day > rule.UntilDay || !storyConditionsMet(state, rule.Conditions) {
				continue
			}
			if selected == nil || rule.Priority > selected.Priority || rule.Priority == selected.Priority && (arcID < selectedArcID || arcID == selectedArcID && rule.ID < selected.ID) {
				selected = rule
				selectedArcID = arcID
			}
		}
	}
	if selected == nil {
		return nil
	}
	location := ""
	if selected.LocationID != "" {
		location = s.visibleLocation(selected.LocationID).Name
	}
	return &RouteProgress{
		ID: selected.RouteID, Label: selected.Label, Status: selected.Status, NextStep: selected.NextStep,
		Window: selected.Window, DeadlineDay: selected.DeadlineDay, Location: location,
		PersonalReturn: selected.PersonalReturn, Urgent: selected.Urgent, Complete: selected.Complete,
	}
}

func (s *Session) storyConsequences(state *domain.WorldState) []string {
	arcIDs := make([]string, 0, len(s.bundle.StoryArcs))
	for arcID := range s.bundle.StoryArcs {
		arcIDs = append(arcIDs, arcID)
	}
	sort.Strings(arcIDs)
	result := make([]string, 0)
	for _, arcID := range arcIDs {
		arc := s.bundle.StoryArcs[arcID]
		stateID := state.StoryStates[arcID]
		for _, rule := range arc.ConsequenceRules {
			if !containsStoryState(rule.States, stateID) || !storyConditionsMet(state, rule.Conditions) {
				continue
			}
			text := rule.Text
			if rule.RelationMetric != "" {
				fromID := materializeStoryActorID(rule.RelationFromID, state.Player.ID)
				toID := materializeStoryActorID(rule.RelationToID, state.Player.ID)
				value := storyRelationMetric(state.RelationBetween(fromID, toID), rule.RelationMetric)
				text = strings.ReplaceAll(text, "{{value}}", fmt.Sprintf("%d", value))
			}
			result = append(result, text)
		}
	}
	return result
}

func (s *Session) storyFeedback(actionID string, state *domain.WorldState) (*domain.StoryFeedback, string) {
	for _, arc := range s.bundle.StoryArcs {
		for _, node := range arc.Nodes {
			for _, choice := range node.Choices {
				if choice.ID != actionID {
					continue
				}
				subjectID := choice.Feedback.Presentation.Subject
				switch subjectID {
				case "target":
					subjectID = node.TargetID
				case "player":
					subjectID = state.Player.ID
				case "fact":
					subjectID = node.FactID
				}
				feedback := choice.Feedback
				return &feedback, subjectID
			}
		}
	}
	return nil, ""
}

func containsStoryState(states []string, stateID string) bool {
	for _, candidate := range states {
		if candidate == stateID {
			return true
		}
	}
	return false
}

func materializeStoryActorID(actorID, playerID string) string {
	if actorID == "player" {
		return playerID
	}
	return actorID
}

func storyRelationMetric(relation domain.Relation, metric string) int {
	switch metric {
	case "trust":
		return relation.Trust
	case "suspicion":
		return relation.Suspicion
	case "fear":
		return relation.Fear
	case "dependence":
		return relation.Dependence
	case "hatred":
		return relation.Hatred
	case "debt":
		return relation.Debt
	default:
		return 0
	}
}

func storyConditionsMet(state *domain.WorldState, conditions []domain.Condition) bool {
	for _, condition := range conditions {
		switch condition.Type {
		case "has_item":
			if state.Player.Items[condition.Key] <= 0 {
				return false
			}
		case "missing_item":
			if state.Player.Items[condition.Key] > 0 {
				return false
			}
		case "flag":
			if condition.Scope == "actor" && !state.ActorFlag(state.Player.ID, condition.Key) || condition.Scope != "actor" && !state.WorldFlag(condition.Key) {
				return false
			}
		case "missing_flag":
			if condition.Scope == "actor" && state.ActorFlag(state.Player.ID, condition.Key) || condition.Scope != "actor" && state.WorldFlag(condition.Key) {
				return false
			}
		default:
			return false
		}
	}
	return true
}

func materializeStoryEffects(source []domain.Effect, playerID, targetID string) []domain.Effect {
	effects := append([]domain.Effect(nil), source...)
	for index := range effects {
		switch effects[index].TargetID {
		case "player":
			effects[index].TargetID = playerID
		case "target":
			effects[index].TargetID = targetID
		}
		if effects[index].FromID == "player" {
			effects[index].FromID = playerID
		} else if effects[index].FromID == "target" {
			effects[index].FromID = targetID
		}
	}
	return effects
}

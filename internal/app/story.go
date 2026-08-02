package app

import "fantu/internal/domain"

func (s *Session) addStoryInformationActions(options map[string]actionOption, state *domain.WorldState, actor VisibleActor, belief domain.Belief, action domain.ActionDefinition) bool {
	added := false
	for arcID, arc := range s.bundle.StoryArcs {
		for _, node := range arc.Nodes {
			if state.StoryStates[arcID] != node.FromState || node.ActionID != action.ID || node.TargetID != actor.ID || node.FactID != belief.FactID || belief.Confidence < node.MinConfidence {
				continue
			}
			for _, choice := range node.Choices {
				if !storyConditionsMet(state, choice.Conditions) {
					continue
				}
				relevance, risk := s.publicInformationContext(actor.ID, s.bundle.Facts[node.FactID])
				effects := []domain.Effect{{
					Type: "set_belief", TargetID: actor.ID, FactID: node.FactID, Claim: belief.Claim,
					Confidence: belief.Confidence, EvidenceStrength: belief.EvidenceStrength,
					Source: state.Player.ID, Propagation: "private", Secrecy: belief.Secrecy,
				}}
				effects = append(effects, materializeStoryEffects(choice.Effects, state.Player.ID, actor.ID)...)
				effects = append(effects, domain.Effect{Type: "set_story_state", Key: arcID, Value: choice.ToState})
				conditions := []domain.Condition{{Type: "belief", Key: node.FactID, MinConfidence: node.MinConfidence}, {Type: "location", Value: state.Player.Location}}
				conditions = append(conditions, choice.Conditions...)
				options[choice.ID] = actionOption{
					view: AvailableAction{
						ID: choice.ID, Kind: "tell", Category: "information", Name: choice.Name, Description: choice.Description,
						Duration: action.Duration, TargetID: actor.ID, TargetName: actor.Name, TargetRole: actor.PublicRole,
						FactID: node.FactID, FactClaim: belief.Claim, TermID: choice.TermID, TermLabel: choice.TermLabel,
						PersonalOutcome: choice.PersonalOutcome, Relevance: relevance, Risk: risk,
						ExpectedOutcomes: append([]string(nil), choice.ExpectedOutcomes...), Warnings: append([]string(nil), choice.Warnings...),
						Irreversible: choice.Irreversible,
					},
					command: &domain.PlayerCommand{
						ActionID: action.ID, TargetID: actor.ID, Description: choice.Description,
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

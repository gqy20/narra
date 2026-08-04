package app

import (
	"sort"

	"narra/internal/domain"
)

func (s *Session) visibleActorPlans(state *domain.WorldState) []VisibleActorPlan {
	result := make([]VisibleActorPlan, 0)
	for _, config := range s.bundle.NPCs {
		if !config.TrackPublicPlan {
			continue
		}
		actorID := config.ID
		npc, ok := state.NPCs[actorID]
		if !ok {
			continue
		}
		plan := VisibleActorPlan{
			ID: actorID, Name: npc.Name, Faction: npc.Faction,
			LocationID: npc.Location, LocationName: s.visibleLocation(npc.Location).Name,
			PublicGoal: config.PublicGoal, Status: "观望",
			Plan: "观察各方动向", Reason: "尚未掌握足以改变公开安排的可靠消息",
		}

		var strategy domain.Strategy
		var decision *domain.DecisionRecord
		if npc.Pending != nil {
			strategy = npc.Pending.Intent.Strategy
			plan.Status = "行动中"
			plan.ExpectedDay = npc.Pending.CompleteDay
		} else if latest := latestActorDecision(state.Decisions, actorID); latest != nil && len(latest.Choices) > 0 {
			copy := *latest
			decision = &copy
			choice := latest.Choices[0]
			strategy = strategyByID(config.Strategies, choice.StrategyID)
			strategy.ID = choice.StrategyID
			if strategy.Description == "" {
				strategy.Description = choice.Description
			}
			strategy.Generated = choice.Generated
			if !choice.Generated {
				plan.Status = "谋划中"
				if latest.Day == state.Day {
					plan.Status = "刚刚行动"
				}
			}
		}

		if strategy.Description != "" && !strategy.Generated {
			plan.Plan = strategy.Description
			if strategy.PublicDescription != "" {
				plan.Plan = strategy.PublicDescription
			}
			plan.Reason = s.visiblePlanReason(state, npc, strategy)
			if plan.ExpectedDay == 0 {
				plan.ExpectedDay = state.Day + maxInt(0, s.strategyDuration(strategy)-1)
			}
			plan.DestinationID = strategyDestination(strategy)
			if plan.DestinationID != "" {
				plan.DestinationName = s.visibleLocation(plan.DestinationID).Name
			}
		}
		plan.InfluencedByPlayer, plan.ChangedByPlayer, plan.PreviousPlan = s.playerPlanInfluence(state, npc, strategy, decision)
		if plan.InfluencedByPlayer && !plan.ChangedByPlayer && strategy.Description != "" {
			plan.Reason = "你的介入成为这项安排的依据之一；" + plan.Reason
		}
		result = append(result, plan)
	}
	sort.Slice(result, func(i, j int) bool { return result[i].ID < result[j].ID })
	return result
}

func (s *Session) actorConfig(actorID string) domain.NPCConfig {
	for _, config := range s.bundle.NPCs {
		if config.ID == actorID {
			return config
		}
	}
	return domain.NPCConfig{}
}

func latestActorDecision(decisions []domain.DecisionRecord, actorID string) *domain.DecisionRecord {
	for index := len(decisions) - 1; index >= 0; index-- {
		if decisions[index].ActorID == actorID {
			return &decisions[index]
		}
	}
	return nil
}

func strategyByID(strategies []domain.Strategy, strategyID string) domain.Strategy {
	for _, strategy := range strategies {
		if strategy.ID == strategyID {
			return strategy
		}
	}
	return domain.Strategy{}
}

func (s *Session) strategyDuration(strategy domain.Strategy) int {
	if strategy.Duration > 0 {
		return strategy.Duration
	}
	if action, ok := s.bundle.Actions[strategy.ActionID]; ok && action.Duration > 0 {
		return action.Duration
	}
	return 1
}

func strategyDestination(strategy domain.Strategy) string {
	for _, effect := range strategy.Effects {
		if effect.Type == "move" {
			return effect.Value
		}
	}
	return ""
}

func (s *Session) visiblePlanReason(state *domain.WorldState, npc *domain.NPCState, strategy domain.Strategy) string {
	for _, condition := range strategy.Conditions {
		switch condition.Type {
		case "belief", "belief_max":
			belief, ok := npc.Beliefs[condition.Key]
			if !ok {
				continue
			}
			if belief.Source == state.Player.ID {
				return s.uiText("plan_player_information", "claim", belief.Claim)
			}
			if _, known := state.Player.Beliefs[condition.Key]; known {
				return s.uiText("plan_shared_information", "claim", belief.Claim)
			}
			return s.uiText("plan_private_information")
		case "flag":
			return s.uiText("plan_flag_ready", "condition", s.planFlagLabel(condition))
		case "has_item":
			name := condition.Key
			if item, ok := s.bundle.Items[condition.Key]; ok {
				name = item.Name
			}
			return s.uiText("plan_has_item", "name", name)
		case "missing_item":
			name := condition.Key
			if item, ok := s.bundle.Items[condition.Key]; ok {
				name = item.Name
			}
			return s.uiText("plan_missing_item", "name", name)
		}
	}
	if strategy.Description != "" {
		return s.uiText("plan_public_goal")
	}
	return s.uiText("plan_unavailable")
}

func (s *Session) planFlagLabel(condition domain.Condition) string {
	scope := condition.Scope
	if scope == "" {
		scope = "world"
	}
	if flag, ok := s.bundle.Flags[scope+":"+condition.Key]; ok && flag.PublicLabel != "" {
		return flag.PublicLabel
	}
	return s.uiText("plan_flag_changed")
}

func (s *Session) playerPlanInfluence(state *domain.WorldState, npc *domain.NPCState, strategy domain.Strategy, decision *domain.DecisionRecord) (bool, bool, string) {
	influenced := false
	for _, condition := range strategy.Conditions {
		switch condition.Type {
		case "belief", "belief_max":
			if belief, ok := npc.Beliefs[condition.Key]; ok && belief.Source == state.Player.ID {
				influenced = true
			}
		case "flag":
			if s.eventCausedByPlayer(state, state.WorldFlagSources[condition.Key]) || s.eventCausedByPlayer(state, state.ActorFlagSources[npc.ID][condition.Key]) {
				influenced = true
			}
		}
	}
	if decision == nil {
		return influenced, false, ""
	}
	for _, counterfactual := range decision.Counterfactuals {
		if !counterfactual.Changed || !s.eventCausedByPlayer(state, counterfactual.TriggerEventID) {
			continue
		}
		previous := s.strategyDescription(npc.ID, counterfactual.AlternativeStrategyID, decision.Choices, "原有安排")
		return true, true, previous
	}
	return influenced, false, ""
}

func (s *Session) eventCausedByPlayer(state *domain.WorldState, eventID string) bool {
	if eventID == "" {
		return false
	}
	for _, event := range state.Events {
		if event.ID == eventID {
			return event.ActorID == state.Player.ID
		}
	}
	return false
}

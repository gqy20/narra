package app

import (
	"fmt"
	"sort"

	"fantu/internal/domain"
)

var trackedActorPlanIDs = map[string]bool{"N03": true, "N06": true, "N09": true}

func (s *Session) visibleActorPlans(state *domain.WorldState) []VisibleActorPlan {
	result := make([]VisibleActorPlan, 0, len(trackedActorPlanIDs))
	for actorID := range trackedActorPlanIDs {
		npc, ok := state.NPCs[actorID]
		if !ok {
			continue
		}
		config := s.actorConfig(actorID)
		plan := VisibleActorPlan{
			ID: actorID, Name: npc.Name, Faction: npc.Faction,
			LocationID: npc.Location, LocationName: s.visibleLocation(npc.Location).Name,
			PublicGoal: publicActorGoal(actorID, config.Goal), Status: "观望",
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
			plan.Plan = publicPlanLabel(strategy.ID, strategy.Description)
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

func publicActorGoal(actorID, fallback string) string {
	switch actorID {
	case "N03":
		return "代表青岚门完成入谷准备并取得灵药"
	case "N06":
		return "保存青髓芝药性并争取研究机会"
	case "N09":
		return "维护宗门审核与内部秩序"
	default:
		return fallback
	}
}

func publicPlanLabel(strategyID, fallback string) string {
	switch strategyID {
	case "N09-spread-false-date":
		return "把一则成熟日期传闻带入坊市"
	case "N09-challenge-player-source":
		return "公开质疑玩家与沈砚秋的消息来源"
	default:
		return fallback
	}
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
				return fmt.Sprintf("采用了你提供的消息：“%s”", belief.Claim)
			}
			if _, known := state.Player.Beliefs[condition.Key]; known {
				return fmt.Sprintf("依据双方都已掌握的线索：“%s”", belief.Claim)
			}
			return "依据自己掌握、但尚未向你公开的消息"
		case "flag":
			return "局势条件已经满足：" + planFlagLabel(condition.Key)
		case "has_item":
			name := condition.Key
			if item, ok := s.bundle.Items[condition.Key]; ok {
				name = item.Name
			}
			return "手中已有行动所需的" + name
		case "missing_item":
			name := condition.Key
			if item, ok := s.bundle.Items[condition.Key]; ok {
				name = item.Name
			}
			return "为了补足缺少的" + name
		}
	}
	if strategy.Description != "" {
		return "这项行动最符合其当前公开目标"
	}
	return "尚未形成可以观察的公开计划"
}

func planFlagLabel(flag string) string {
	labels := map[string]string{
		"valley_open": "黑风谷入口已经开放", "transplant_backed": "提前移植方案获得支持",
		"qinglan_review": "青岚门进入公开审核", "player_backed_shen": "你已公开支持沈砚秋",
		"antidote_blockade": "坊市解瘴丹供应被封锁", "player_took_shen_antidote": "你带走了青岚门的解瘴丹",
	}
	if label, ok := labels[flag]; ok {
		return label
	}
	return "局势条件已经发生变化"
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

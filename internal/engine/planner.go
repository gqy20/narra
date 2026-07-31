package engine

import "fantu/internal/domain"

// genericStrategies supplies conservative fallback plans when none of the
// scenario-authored strategies is currently legal. In unified_score mode they
// enter the same scored candidate pool as authored strategies.
func (e *Engine) genericStrategies(state *domain.WorldState, npc *domain.NPCState) []domain.Strategy {
	var strategies []domain.Strategy
	strategies = append(strategies, e.genericNavigationStrategies(state, npc)...)
	strategies = append(strategies, e.genericInvestigationStrategies(npc)...)
	if _, ok := e.bundle.Actions["heal"]; ok && npc.Injury >= 2 {
		strategies = append(strategies, domain.Strategy{
			ID: "generic-heal", ActionID: "heal", Description: npc.Name + "暂缓原计划并处理伤势",
			Generated: true, GoalTypes: []string{"avoid"}, Conditions: []domain.Condition{{Type: "injury_at_least", MinConfidence: 2}},
			Score:   domain.ScoreInput{Goal: 4, Urgency: 5, Probability: 5, Cost: 1},
			Effects: []domain.Effect{{Type: "adjust_injury", Amount: -1}},
		})
	}
	if _, ok := e.bundle.Actions["cultivate"]; ok && !npc.Completed["generic-cultivate"] && npc.Injury == 0 && npc.Resources["combat"] <= 3 && shouldCultivate(npc) {
		strategies = append(strategies, domain.Strategy{
			ID: "generic-cultivate", ActionID: "cultivate", Description: npc.Name + "利用空档修炼并巩固状态",
			Once: true, Generated: true, GoalTypes: []string{"status"},
			Conditions: []domain.Condition{{Type: "injury_at_most", MaxConfidence: 0}, {Type: "resource_at_most", Key: "combat", MaxConfidence: 3}},
			Score:      domain.ScoreInput{Goal: 3, Urgency: 2, Probability: 5, Cost: 2},
			Effects:    []domain.Effect{{Type: "adjust_resource", Key: "combat", Amount: 1}},
		})
	}
	if _, ok := e.bundle.Actions["buy"]; ok && !npc.Completed["generic-buy-antidote"] && npc.Items["antidote"] == 0 && needsAntidote(npc) {
		if marketID, price, available := e.marketOffer(npc.ID, "antidote", 1); available && npc.Resources["spirit_stones"] >= price {
			strategies = append(strategies, domain.Strategy{
				ID: "generic-buy-antidote", ActionID: "buy", Description: npc.Name + "为可能的黑风谷行动补充解瘴丹",
				Once: true, Generated: true, GoalTypes: []string{"avoid", "acquire"},
				Conditions: []domain.Condition{{Type: "missing_item", Key: "antidote"}, {Type: "resource_at_least", Key: "spirit_stones", MinConfidence: price}},
				Score:      domain.ScoreInput{Goal: 2, Urgency: 3, Probability: 5, Cost: 2},
				Costs:      map[string]int{"spirit_stones": price},
				Effects:    []domain.Effect{{Type: "market_buy", Value: marketID, Key: "antidote", Amount: 1}},
			})
		}
	}

	result := strategies[:0]
	for _, strategy := range strategies {
		duration := e.bundle.Actions[strategy.ActionID].Duration
		if duration <= 0 {
			duration = 1
		}
		if state.Day+duration-1 > e.bundle.Scenario.Duration {
			continue
		}
		if e.bundle.Scenario.PlanningMode == "unified_score" || strategy.ActionID == "flee" || !overlapsAuthoredWindow(state.Day, state.Day+duration-1, e.bundle.Scenario.Duration, npc) {
			result = append(result, strategy)
		}
	}
	return result
}

func shouldCultivate(npc *domain.NPCState) bool {
	if npc.Personality.Ambition >= 4 {
		return true
	}
	for _, actionID := range []string{"explore", "track", "ambush", "flee", "prepare_breakthrough"} {
		if hasAuthoredAction(npc, actionID) {
			return true
		}
	}
	return false
}

func needsAntidote(npc *domain.NPCState) bool {
	for _, strategy := range npc.Strategies {
		for _, condition := range strategy.Conditions {
			if condition.Type == "has_item" && condition.Key == "antidote" {
				return true
			}
		}
	}
	if len(npc.Strategies) != 0 {
		return false
	}
	for _, factID := range []string{"F01", "F04"} {
		if belief, ok := npc.Beliefs[factID]; ok && belief.Confidence >= 2 {
			return true
		}
	}
	return false
}

func hasAuthoredAction(npc *domain.NPCState, actionID string) bool {
	for _, strategy := range npc.Strategies {
		if strategy.ActionID == actionID {
			return true
		}
	}
	return false
}

func overlapsAuthoredWindow(fromDay, toDay, horizon int, npc *domain.NPCState) bool {
	for _, strategy := range npc.Strategies {
		if strategy.Once && npc.Completed[strategy.ID] {
			continue
		}
		strategyTo := strategy.UntilDay
		if strategyTo == 0 {
			strategyTo = horizon
		}
		if fromDay <= strategyTo && toDay >= strategy.FromDay {
			return true
		}
	}
	return false
}

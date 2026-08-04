package engine

import (
	"strings"

	"narra/internal/domain"
)

// genericStrategies supplies conservative fallback plans when none of the
// scenario-authored strategies is currently legal. In unified_score mode they
// enter the same scored candidate pool as authored strategies.
func (e *Engine) genericStrategies(state *domain.WorldState, npc *domain.NPCState) []domain.Strategy {
	var strategies []domain.Strategy
	strategies = append(strategies, e.genericNavigationStrategies(state, npc)...)
	strategies = append(strategies, e.genericInvestigationStrategies(npc)...)
	for _, definition := range e.bundle.Rules.FallbackStrategies {
		strategy := definition.Strategy
		if strategy.Once && npc.Completed[strategy.ID] || definition.RequireNoAuthoredStrategies && len(npc.Strategies) > 0 || !anyConditionMet(state, npc, definition.AnyConditions) || !personalityThresholdsMet(npc.Personality, definition.PersonalityAtLeast) {
			continue
		}
		strategy.Generated = true
		strategy.Description = strings.ReplaceAll(strategy.Description, "{actor}", npc.Name)
		strategy.Conditions = append([]domain.Condition(nil), strategy.Conditions...)
		strategy.Effects = append([]domain.Effect(nil), strategy.Effects...)
		strategy.GoalTypes = append([]string(nil), strategy.GoalTypes...)
		strategy.Costs = copyIntMap(strategy.Costs)
		if purchase := definition.MarketPurchase; purchase != nil {
			amount := purchase.Amount
			if amount <= 0 {
				amount = 1
			}
			marketID, currency, price, available := e.marketOffer(npc.ID, purchase.ItemID, amount)
			if !available || npc.Resources[currency] < price {
				continue
			}
			strategy.Conditions = append(strategy.Conditions, domain.Condition{Type: domain.ConditionResourceAtLeast, Key: currency, MinConfidence: price})
			strategy.Costs[currency] = price
			strategy.Effects = append(strategy.Effects, domain.Effect{Type: domain.EffectMarketBuy, Value: marketID, Key: purchase.ItemID, Amount: amount})
		}
		strategies = append(strategies, strategy)
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
		retreat := e.bundle.Rules.Navigation.Retreat
		if e.bundle.Scenario.PlanningMode == "unified_score" || retreat.Enabled && strategy.ActionID == retreat.ActionID || !overlapsAuthoredWindow(state.Day, state.Day+duration-1, e.bundle.Scenario.Duration, npc) {
			result = append(result, strategy)
		}
	}
	return result
}

func personalityThresholdsMet(personality domain.Personality, thresholds map[string]int) bool {
	for key, threshold := range thresholds {
		value := 0
		switch key {
		case "caution":
			value = personality.Caution
		case "greed":
			value = personality.Greed
		case "loyalty":
			value = personality.Loyalty
		case "ambition":
			value = personality.Ambition
		case "credit":
			value = personality.Credit
		case "risk_tolerance":
			value = personality.RiskTolerance
		default:
			return false
		}
		if value < threshold {
			return false
		}
	}
	return true
}

func anyConditionMet(state *domain.WorldState, npc *domain.NPCState, conditions []domain.Condition) bool {
	if len(conditions) == 0 {
		return true
	}
	for _, condition := range conditions {
		if conditionsMet(state, npc, []domain.Condition{condition}) {
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

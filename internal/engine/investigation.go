package engine

import (
	"sort"
	"strings"

	"narra/internal/domain"
)

func (e *Engine) genericInvestigationStrategies(npc *domain.NPCState) []domain.Strategy {
	rule := e.bundle.Rules.Investigation
	if !rule.Enabled {
		return nil
	}
	factIDs := make([]string, 0, len(npc.Beliefs))
	for factID := range npc.Beliefs {
		factIDs = append(factIDs, factID)
	}
	sort.Strings(factIDs)
	strategies := make([]domain.Strategy, 0)
	for _, factID := range factIDs {
		belief := npc.Beliefs[factID]
		fact, ok := e.bundle.Facts[factID]
		if !ok || !fact.Discoverable || belief.Confidence < 1 || belief.Confidence >= 3 || !sharesTopic(npc.Interests, fact.Topics) {
			continue
		}
		strategyID := "generic-verify-" + factID
		if npc.Completed[strategyID] {
			continue
		}
		source := "investigation:" + factID
		effects := []domain.Effect{{Type: "set_belief", FactID: factID, Confidence: 3, Source: source}}
		for _, lead := range fact.Leads {
			effects = append(effects, domain.Effect{Type: "set_belief", FactID: lead.FactID, Confidence: lead.Confidence, Source: source})
		}
		strategies = append(strategies, domain.Strategy{
			ID: strategyID, ActionID: rule.ActionID, Description: strings.NewReplacer("{actor}", npc.Name, "{fact}", factID).Replace(rule.Description),
			Once: true, Generated: true, GoalTypes: append([]string(nil), rule.GoalTypes...),
			Conditions: []domain.Condition{{Type: "belief", Key: factID, MinConfidence: 1}, {Type: "belief_max", Key: factID, MaxConfidence: 2}},
			Score:      rule.Score,
			Effects:    effects,
		})
	}
	return strategies
}

func sharesTopic(interests, topics []string) bool {
	for _, interest := range interests {
		for _, topic := range topics {
			if interest == topic {
				return true
			}
		}
	}
	return false
}

package engine

import "narra/internal/domain"

func (e *Engine) auditDecision(state *domain.WorldState, actorID string, strategies []domain.Strategy, selectedID string, record *domain.DecisionRecord) {
	withoutRelations := cloneWorld(state)
	relevant := false
	for key, relation := range withoutRelations.Relations {
		if relation.From == actorID && relationshipModifier(state, relation.From, relation.To) != 0 {
			relevant = true
			delete(withoutRelations.Relations, key)
		}
	}
	if relevant {
		record.RelationshipRelevant = true
		choices := e.rankChoices(withoutRelations, withoutRelations.NPCs[actorID], strategies)
		if len(choices) > 0 {
			record.WithoutRelationshipStrategyID = choices[0].StrategyID
			record.RelationshipChangedTop = choices[0].StrategyID != selectedID
		}
	}

	selected := findStrategy(strategies, selectedID)
	seen := make(map[string]bool)
	for _, condition := range selected.Conditions {
		kind, key := removableInformation(condition)
		if kind == "" || seen[kind+":"+key] {
			continue
		}
		seen[kind+":"+key] = true
		variant := cloneWorld(state)
		triggerID := removeInformation(variant, actorID, condition)
		if triggerID == "" {
			continue
		}
		choices := e.rankChoices(variant, variant.NPCs[actorID], strategies)
		alternative := ""
		if len(choices) > 0 {
			alternative = choices[0].StrategyID
		}
		record.Counterfactuals = append(record.Counterfactuals, domain.CounterfactualRecord{
			Kind: kind, RemovedKey: key, TriggerEventID: triggerID, OriginalStrategyID: selectedID,
			AlternativeStrategyID: alternative, Changed: alternative != selectedID,
		})
	}
}

func removableInformation(condition domain.Condition) (string, string) {
	switch condition.Type {
	case "belief", "belief_max":
		return "belief", condition.Key
	case "flag":
		return "flag", condition.Key
	case "has_item":
		return "item", condition.Key
	case "opportunity":
		return "opportunity", condition.Key
	default:
		return "", ""
	}
}

func removeInformation(state *domain.WorldState, actorID string, condition domain.Condition) string {
	switch condition.Type {
	case "belief", "belief_max":
		belief := state.NPCs[actorID].Beliefs[condition.Key]
		delete(state.NPCs[actorID].Beliefs, condition.Key)
		return belief.SourceEventID
	case "flag":
		if condition.Scope == "actor" {
			trigger := state.ActorFlagSources[actorID][condition.Key]
			delete(state.ActorFlags[actorID], condition.Key)
			return trigger
		}
		trigger := state.WorldFlagSources[condition.Key]
		delete(state.WorldFlags, condition.Key)
		return trigger
	case "has_item":
		trigger := state.ItemSources[condition.Key]
		delete(state.NPCs[actorID].Items, condition.Key)
		return trigger
	case "opportunity":
		trigger := state.OpportunitySources[condition.Key]
		delete(state.Opportunities, condition.Key)
		return trigger
	default:
		return ""
	}
}

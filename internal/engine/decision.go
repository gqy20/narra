package engine

import "narra/internal/domain"

func calculateScore(personality domain.Personality, input domain.ScoreInput, relationModifier int) domain.ScoreBreakdown {
	personalityModifier := 0
	if input.Goal > 0 {
		personalityModifier += (personality.Ambition - 2)
	}
	if input.Cost > 0 {
		personalityModifier += (personality.Greed - 2)
	}
	if input.Danger > 0 {
		personalityModifier += personality.RiskTolerance - personality.Caution
	}
	relationship := input.Relationship + relationModifier
	total := input.Base + 3*input.Goal + 2*input.Urgency + 2*input.Probability +
		input.Information + relationship - 2*input.Cost - 2*input.Danger + personalityModifier
	return domain.ScoreBreakdown{
		Base: input.Base, Goal: input.Goal, Urgency: input.Urgency,
		Probability: input.Probability, Information: input.Information,
		Relationship: relationship, Cost: input.Cost, Danger: input.Danger,
		Personality: personalityModifier, Total: total,
	}
}

func relationshipModifier(state *domain.WorldState, from, to string) int {
	if to == "" {
		return 0
	}
	relation := state.RelationBetween(from, to)
	value := relation.Trust + relation.Dependence + relation.Debt - relation.Suspicion - relation.Hatred
	if value > 5 {
		return 5
	}
	if value < -5 {
		return -5
	}
	return value
}

func conditionsMet(state *domain.WorldState, npc *domain.NPCState, conditions []domain.Condition) bool {
	for _, condition := range conditions {
		switch condition.Type {
		case "belief":
			belief, ok := npc.Beliefs[condition.Key]
			if !ok || belief.Confidence < condition.MinConfidence {
				return false
			}
		case "belief_max":
			belief, ok := npc.Beliefs[condition.Key]
			if !ok || belief.Confidence > condition.MaxConfidence {
				return false
			}
		case "has_item":
			if npc.Items[condition.Key] <= 0 {
				return false
			}
		case "missing_item":
			if npc.Items[condition.Key] > 0 {
				return false
			}
		case "location":
			if npc.Location != condition.Value {
				return false
			}
		case "flag":
			if !conditionFlag(state, npc.ID, condition) {
				return false
			}
		case "missing_flag":
			if conditionFlag(state, npc.ID, condition) {
				return false
			}
		case "resource_at_least":
			if npc.Resources[condition.Key] < condition.MinConfidence {
				return false
			}
		case "resource_at_most":
			if npc.Resources[condition.Key] > condition.MaxConfidence {
				return false
			}
		case "injury_at_least":
			if npc.Injury < condition.MinConfidence {
				return false
			}
		case "injury_at_most":
			if npc.Injury > condition.MaxConfidence {
				return false
			}
		default:
			return false
		}
	}
	return true
}

func playerConditionsMet(state *domain.WorldState, player *domain.PlayerState, conditions []domain.Condition) bool {
	for _, condition := range conditions {
		switch condition.Type {
		case "belief":
			belief, ok := player.Beliefs[condition.Key]
			if !ok || belief.Confidence < condition.MinConfidence {
				return false
			}
		case "belief_max":
			belief, ok := player.Beliefs[condition.Key]
			if !ok || belief.Confidence > condition.MaxConfidence {
				return false
			}
		case "has_item":
			if player.Items[condition.Key] <= 0 {
				return false
			}
		case "missing_item":
			if player.Items[condition.Key] > 0 {
				return false
			}
		case "location":
			if player.Location != condition.Value {
				return false
			}
		case "resource_at_least":
			if player.Resources[condition.Key] < condition.MinConfidence {
				return false
			}
		case "resource_at_most":
			if player.Resources[condition.Key] > condition.MaxConfidence {
				return false
			}
		case "injury_at_least":
			if player.Injury < condition.MinConfidence {
				return false
			}
		case "injury_at_most":
			if player.Injury > condition.MaxConfidence {
				return false
			}
		case "opportunity":
			if _, ok := state.Opportunities[condition.Key]; !ok {
				return false
			}
		case "flag":
			if !conditionFlag(state, player.ID, condition) {
				return false
			}
		case "missing_flag":
			if conditionFlag(state, player.ID, condition) {
				return false
			}
		default:
			return false
		}
	}
	return true
}

func conditionFlag(state *domain.WorldState, actorID string, condition domain.Condition) bool {
	if condition.Scope == "actor" {
		return state.ActorFlag(actorID, condition.Key)
	}
	return state.WorldFlag(condition.Key)
}

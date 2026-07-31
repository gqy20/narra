package engine

import (
	"sort"

	"fantu/internal/domain"
)

func collectTriggerEvents(state *domain.WorldState, actorID string, beliefs map[string]domain.Belief, conditions []domain.Condition) []string {
	seen := make(map[string]bool)
	for _, condition := range conditions {
		eventID := ""
		switch condition.Type {
		case "belief", "belief_max":
			eventID = beliefs[condition.Key].SourceEventID
		case "flag", "missing_flag":
			if condition.Scope == "actor" {
				eventID = state.ActorFlagSources[actorID][condition.Key]
			} else {
				eventID = state.WorldFlagSources[condition.Key]
			}
		case "has_item", "missing_item":
			eventID = state.ItemSources[condition.Key]
		case "opportunity":
			eventID = state.OpportunitySources[condition.Key]
		}
		if eventID != "" {
			seen[eventID] = true
		}
	}
	ids := make([]string, 0, len(seen))
	for eventID := range seen {
		ids = append(ids, eventID)
	}
	sort.Strings(ids)
	return ids
}

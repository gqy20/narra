package engine

import (
	"fmt"
	"sort"

	"fantu/internal/domain"
)

func (e *Engine) genericNavigationStrategies(state *domain.WorldState, npc *domain.NPCState) []domain.Strategy {
	currentLocation, knownLocation := e.bundle.Locations[npc.Location]
	if npc.Injury >= 2 && knownLocation && !currentLocation.Safe {
		if route, _, ok := e.pathToNearestSafe(state, npc); ok {
			return []domain.Strategy{navigationStrategy(npc, route, "flee", "撤往安全地点", 5, 5)}
		}
	}
	if e.bundle.Scenario.DisableGenericContestNavigation {
		return nil
	}
	contest := e.bundle.Scenario.Contest
	if state.Day > contest.Day || state.Items[contest.ItemID] != contest.LocationID || !wantsContest(npc) {
		return nil
	}
	route, totalDuration, ok := e.shortestPath(state, npc, npc.Location, contest.LocationID, false)
	if !ok || state.Day+totalDuration-1 > contest.Day {
		return nil
	}
	return []domain.Strategy{navigationStrategy(npc, route, "explore", "沿可行路线接近争夺目标", 4, 4)}
}

func navigationStrategy(npc *domain.NPCState, route domain.Route, actionID, purpose string, goal, urgency int) domain.Strategy {
	conditions := []domain.Condition{{Type: "location", Value: npc.Location}}
	if route.RequiredItem != "" {
		conditions = append(conditions, domain.Condition{Type: "has_item", Key: route.RequiredItem})
	}
	if route.RequiredFlag != "" {
		conditions = append(conditions, domain.Condition{Type: "flag", Key: route.RequiredFlag})
	}
	base := 0
	if actionID == "flee" {
		base = 8
	}
	return domain.Strategy{
		ID: fmt.Sprintf("generic-%s-%s-%s", actionID, npc.Location, route.To), ActionID: actionID,
		Description: fmt.Sprintf("%s%s：%s → %s", npc.Name, purpose, npc.Location, route.To),
		Duration:    route.Duration, Generated: true, Conditions: conditions,
		GoalTypes: navigationGoalTypes(actionID),
		Score:     domain.ScoreInput{Base: base, Goal: goal, Urgency: urgency, Probability: 4, Cost: route.Duration, Danger: route.Danger},
		Effects:   []domain.Effect{{Type: "move", Value: route.To}},
	}
}

func navigationGoalTypes(actionID string) []string {
	if actionID == "flee" {
		return []string{"avoid"}
	}
	return []string{"acquire"}
}

func wantsContest(npc *domain.NPCState) bool {
	if npc.Personality.Ambition < 3 || npc.Injury >= 3 {
		return false
	}
	if belief, ok := npc.Beliefs["F09"]; ok && belief.Confidence >= 2 {
		return false
	}
	for _, factID := range []string{"F01", "F04"} {
		if belief, ok := npc.Beliefs[factID]; ok && belief.Confidence >= 2 {
			return true
		}
	}
	return false
}

func (e *Engine) pathToNearestSafe(state *domain.WorldState, npc *domain.NPCState) (domain.Route, int, bool) {
	safeIDs := make([]string, 0)
	for id, location := range e.bundle.Locations {
		if location.Safe && id != npc.Location {
			safeIDs = append(safeIDs, id)
		}
	}
	sort.Strings(safeIDs)
	bestDuration := int(^uint(0) >> 1)
	var best domain.Route
	found := false
	for _, destination := range safeIDs {
		route, duration, ok := e.shortestPath(state, npc, npc.Location, destination, true)
		if ok && duration < bestDuration {
			best, bestDuration, found = route, duration, true
		}
	}
	return best, bestDuration, found
}

func (e *Engine) shortestPath(state *domain.WorldState, npc *domain.NPCState, from, to string, retreat bool) (domain.Route, int, bool) {
	if from == to {
		return domain.Route{}, 0, false
	}
	const infinity = int(^uint(0) >> 1)
	distance := make(map[string]int, len(e.bundle.Locations))
	first := make(map[string]domain.Route, len(e.bundle.Locations))
	visited := make(map[string]bool, len(e.bundle.Locations))
	for id := range e.bundle.Locations {
		distance[id] = infinity
	}
	distance[from] = 0
	for {
		current := ""
		best := infinity
		ids := make([]string, 0, len(e.bundle.Locations))
		for id := range e.bundle.Locations {
			ids = append(ids, id)
		}
		sort.Strings(ids)
		for _, id := range ids {
			if !visited[id] && distance[id] < best {
				current, best = id, distance[id]
			}
		}
		if current == "" || current == to {
			break
		}
		visited[current] = true
		for _, route := range e.bundle.Locations[current].Routes {
			if !routeAvailable(state, npc, route, retreat) {
				continue
			}
			candidate := distance[current] + route.Duration
			if candidate < distance[route.To] {
				distance[route.To] = candidate
				if current == from {
					first[route.To] = route
				} else {
					first[route.To] = first[current]
				}
			}
		}
	}
	if distance[to] == infinity {
		return domain.Route{}, 0, false
	}
	return first[to], distance[to], true
}

func routeAvailable(state *domain.WorldState, npc *domain.NPCState, route domain.Route, retreat bool) bool {
	if route.RequiredItem != "" && npc.Items[route.RequiredItem] <= 0 {
		return false
	}
	if route.RequiredFlag != "" && !state.WorldFlag(route.RequiredFlag) && !retreat {
		return false
	}
	return true
}

package app

import (
	"sort"
	"strconv"
	"unicode"

	"fantu/internal/domain"
)

func (s *Session) travelGuidance(state *domain.WorldState) *TravelGuidance {
	destinationID := s.bundle.Scenario.Contest.LocationID
	destination, exists := s.bundle.Locations[destinationID]
	if !exists {
		return nil
	}
	routes, days, ok := s.shortestPublicRoute(state.Player.Location, destinationID)
	if !ok {
		return &TravelGuidance{
			Destination: destination.Name,
			Blockers:    []string{s.uiText("travel_no_route")},
			Checks:      []TravelCheck{{Label: s.uiText("travel_route_found"), Ready: false}},
		}
	}
	guidance := &TravelGuidance{
		Destination: destination.Name,
		TravelDays:  days,
		Checks:      []TravelCheck{{Label: s.uiText("travel_route_found"), Ready: true}},
	}
	if current, found := s.bundle.Locations[state.Player.Location]; found {
		guidance.Route = append(guidance.Route, current.Name)
	}
	seen := make(map[string]bool)
	seenChecks := make(map[string]bool)
	for _, route := range routes {
		if next, found := s.bundle.Locations[route.To]; found {
			guidance.Route = append(guidance.Route, next.Name)
		}
		if route.RequiredItem != "" {
			name := route.RequiredItem
			if item, found := s.bundle.Items[route.RequiredItem]; found {
				name = item.Name
			}
			hasItem := state.Player.Items[route.RequiredItem] > 0
			appendTravelCheck(&guidance.Checks, seenChecks, s.uiText("travel_carry_item", "name", name), hasItem)
			if !hasItem {
				appendBlocker(&guidance.Blockers, seen, s.uiText("travel_missing_item", "name", name))
			}
		}
		if route.RequiredFlag != "" {
			flagReady := state.WorldFlag(route.RequiredFlag)
			appendTravelCheck(&guidance.Checks, seenChecks, s.routeFlagCheckLabel(route.RequiredFlag), flagReady)
			if !flagReady {
				appendBlocker(&guidance.Blockers, seen, s.routeFlagLabel(route.RequiredFlag))
			}
		}
	}
	guidance.Ready = len(guidance.Blockers) == 0
	guidance.Timing = s.travelTiming(state, days)
	return guidance
}

func (s *Session) shortestPublicRoute(from, to string) ([]domain.Route, int, bool) {
	if from == to {
		return nil, 0, true
	}
	const infinity = int(^uint(0) >> 1)
	distance := make(map[string]int, len(s.bundle.Locations))
	previous := make(map[string]string)
	previousRoute := make(map[string]domain.Route)
	visited := make(map[string]bool)
	ids := make([]string, 0, len(s.bundle.Locations))
	for id := range s.bundle.Locations {
		distance[id] = infinity
		ids = append(ids, id)
	}
	sort.Strings(ids)
	distance[from] = 0
	for range ids {
		current := ""
		best := infinity
		for _, id := range ids {
			if !visited[id] && distance[id] < best {
				current, best = id, distance[id]
			}
		}
		if current == "" || current == to {
			break
		}
		visited[current] = true
		for _, route := range s.bundle.Locations[current].Routes {
			duration := maxInt(1, route.Duration)
			candidate := distance[current] + duration
			if candidate < distance[route.To] {
				distance[route.To] = candidate
				previous[route.To] = current
				previousRoute[route.To] = route
			}
		}
	}
	if distance[to] == infinity {
		return nil, 0, false
	}
	var reversed []domain.Route
	for current := to; current != from; current = previous[current] {
		route, found := previousRoute[current]
		if !found {
			return nil, 0, false
		}
		reversed = append(reversed, route)
	}
	routes := make([]domain.Route, len(reversed))
	for index := range reversed {
		routes[len(reversed)-1-index] = reversed[index]
	}
	return routes, distance[to], true
}

func (s *Session) travelTiming(state *domain.WorldState, travelDays int) string {
	if travelDays == 0 {
		return s.uiText("travel_already_arrived")
	}
	knownDay, basis, known := playerKnownDate(state.Player.Beliefs, s.bundle.Scenario.Contest)
	if !known {
		return s.uiText("travel_date_unknown")
	}
	latestDeparture := knownDay - travelDays
	basis = s.uiText("confidence_" + basis)
	if state.Day <= latestDeparture {
		return s.uiText("travel_departure_deadline", "basis", basis, "day", intText(latestDeparture))
	}
	return s.uiText("travel_departure_late", "basis", basis)
}

func playerKnownDate(beliefs map[string]domain.Belief, contest domain.Contest) (int, string, bool) {
	if belief, ok := beliefs[contest.VerifiedDateFactID]; contest.VerifiedDateFactID != "" && ok && belief.Confidence >= 3 {
		if day, found := firstNumber(belief.Claim); found {
			return day, "confirmed", true
		}
	}
	if belief, ok := beliefs[contest.RumoredDateFactID]; contest.RumoredDateFactID != "" && ok && belief.Confidence > 0 && belief.Confidence < 3 {
		if day, found := firstNumber(belief.Claim); found {
			return day, "rumored", true
		}
	}
	return 0, "", false
}

func firstNumber(value string) (int, bool) {
	digits := make([]rune, 0)
	for _, character := range value {
		if unicode.IsDigit(character) {
			digits = append(digits, character)
		} else if len(digits) > 0 {
			break
		}
	}
	if len(digits) == 0 {
		return 0, false
	}
	number, err := strconv.Atoi(string(digits))
	return number, err == nil
}

func appendBlocker(blockers *[]string, seen map[string]bool, blocker string) {
	if blocker == "" || seen[blocker] {
		return
	}
	seen[blocker] = true
	*blockers = append(*blockers, blocker)
}

func appendTravelCheck(checks *[]TravelCheck, seen map[string]bool, label string, ready bool) {
	if label == "" || seen[label] {
		return
	}
	seen[label] = true
	*checks = append(*checks, TravelCheck{Label: label, Ready: ready})
}

func (s *Session) routeFlagLabel(flag string) string {
	if definition, ok := s.bundle.Flags["world:"+flag]; ok && definition.BlockedLabel != "" {
		return definition.BlockedLabel
	}
	return s.uiText("travel_condition_blocked")
}

func (s *Session) routeFlagCheckLabel(flag string) string {
	if definition, ok := s.bundle.Flags["world:"+flag]; ok && definition.PublicLabel != "" {
		return definition.PublicLabel
	}
	return s.uiText("travel_condition_ready")
}

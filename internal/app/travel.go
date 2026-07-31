package app

import (
	"fmt"
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
		return &TravelGuidance{Destination: destination.Name, Blockers: []string{"尚未发现可行路线"}}
	}
	guidance := &TravelGuidance{Destination: destination.Name, TravelDays: days}
	seen := make(map[string]bool)
	for _, route := range routes {
		if route.RequiredItem != "" && state.Player.Items[route.RequiredItem] <= 0 {
			name := route.RequiredItem
			if item, found := s.bundle.Items[route.RequiredItem]; found {
				name = item.Name
			}
			appendBlocker(&guidance.Blockers, seen, "缺少"+name)
		}
		if route.RequiredFlag != "" && !state.WorldFlag(route.RequiredFlag) {
			appendBlocker(&guidance.Blockers, seen, routeFlagLabel(route.RequiredFlag))
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
		return "你已经到达核心争夺地点。"
	}
	knownDay, basis, known := playerKnownDate(state.Player.Beliefs)
	if !known {
		return "成熟时间尚未查明，无法判断最晚出发时间。"
	}
	latestDeparture := knownDay - travelDays
	if state.Day <= latestDeparture {
		return fmt.Sprintf("按%s，最晚应在第 %d 天结束前出发。", basis, latestDeparture)
	}
	return fmt.Sprintf("按%s，即使立即出发也可能来不及。", basis)
}

func playerKnownDate(beliefs map[string]domain.Belief) (int, string, bool) {
	if belief, ok := beliefs["F01"]; ok && belief.Confidence >= 3 {
		if day, found := firstNumber(belief.Claim); found {
			return day, "已核实日期", true
		}
	}
	if belief, ok := beliefs["F02"]; ok && belief.Confidence > 0 && belief.Confidence < 3 {
		if day, found := firstNumber(belief.Claim); found {
			return day, "未经核实的传闻", true
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

func routeFlagLabel(flag string) string {
	switch flag {
	case "valley_open":
		return "黑风谷入口尚未开放"
	default:
		return "路线条件尚未满足"
	}
}

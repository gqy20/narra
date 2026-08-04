package engine

import (
	"fmt"

	"narra/internal/domain"
)

func (e *Engine) movementEffectsLegal(effects []domain.Effect, defaultTarget string, actionDuration int) (bool, string) {
	for _, effect := range effects {
		if effect.Type != "move" {
			continue
		}
		targetID := effect.TargetID
		if targetID == "" {
			targetID = defaultTarget
		}
		ok, reason := e.movementLegal(targetID, effect.Value, actionDuration, effect.BypassRouteFlag)
		if !ok {
			return false, reason
		}
	}
	return true, ""
}

func (e *Engine) movementLegal(actorID, destination string, actionDuration int, bypassRouteFlag bool) (bool, string) {
	location, items, ok := e.travelState(actorID)
	if !ok {
		return false, fmt.Sprintf("移动目标 %s 不存在", actorID)
	}
	route, ok := directRoute(e.bundle.Locations[location].Routes, destination)
	if !ok {
		return false, fmt.Sprintf("不存在路线 %s → %s", location, destination)
	}
	if actionDuration > 0 && actionDuration < route.Duration {
		return false, fmt.Sprintf("行动耗时 %d 少于路线最低耗时 %d", actionDuration, route.Duration)
	}
	if route.RequiredItem != "" && items[route.RequiredItem] <= 0 {
		return false, "缺少路线必需物品 " + route.RequiredItem
	}
	if route.RequiredFlag != "" && !e.state.WorldFlag(route.RequiredFlag) && !bypassRouteFlag {
		return false, "路线尚未开放：" + route.RequiredFlag
	}
	return true, ""
}

func (e *Engine) travelState(actorID string) (string, map[string]int, bool) {
	if e.state.Player != nil && e.state.Player.ID == actorID {
		return e.state.Player.Location, e.state.Player.Items, true
	}
	if npc, ok := e.state.NPCs[actorID]; ok {
		return npc.Location, npc.Items, true
	}
	return "", nil, false
}

func directRoute(routes []domain.Route, destination string) (domain.Route, bool) {
	for _, route := range routes {
		if route.To == destination {
			return route, true
		}
	}
	return domain.Route{}, false
}

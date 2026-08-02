package app

import (
	"sort"

	"fantu/internal/domain"
)

func (s *Session) visibleWorldMap(state *domain.WorldState, actions []AvailableAction) VisibleWorldMap {
	moveActions := make(map[string]string)
	for _, action := range actions {
		if action.Kind == "move" && action.TargetID != "" {
			moveActions[action.TargetID] = action.ID
		}
	}

	actorPlans := s.visibleActorPlans(state)
	actorCounts := make(map[string]int)
	for _, actor := range actorPlans {
		actorCounts[actor.LocationID]++
	}
	actorCounts[state.Player.Location] = len(s.visibleActors(state))
	locationIDs := make([]string, 0, len(s.bundle.Locations))
	for id := range s.bundle.Locations {
		locationIDs = append(locationIDs, id)
	}
	sort.Strings(locationIDs)

	worldMap := VisibleWorldMap{
		Locations: make([]VisibleMapLocation, 0, len(locationIDs)),
		Routes:    make([]VisibleMapRoute, 0),
		Actors:    actorPlans,
	}
	for _, id := range locationIDs {
		location := s.bundle.Locations[id]
		visible := VisibleMapLocation{
			ID: id, Name: location.Name, Safe: location.Safe, X: location.MapX, Y: location.MapY,
			SceneKey: location.SceneKey, Description: location.Description, Atmosphere: location.Atmosphere,
			Current: id == state.Player.Location, Contest: id == s.bundle.Scenario.Contest.LocationID,
		}
		visible.ActorCount = actorCounts[id]
		worldMap.Locations = append(worldMap.Locations, visible)

		for _, route := range location.Routes {
			visibleRoute := VisibleMapRoute{
				FromID: id, ToID: route.To, Duration: maxInt(1, route.Duration), Danger: route.Danger,
				Status: "known",
			}
			if id == state.Player.Location {
				visibleRoute.Blockers = s.visibleRouteBlockers(state, route)
				if actionID, available := moveActions[route.To]; available {
					visibleRoute.Status = "available"
					visibleRoute.ActionID = actionID
				} else {
					visibleRoute.Status = "blocked"
					if len(visibleRoute.Blockers) == 0 {
						visibleRoute.Blockers = []string{"当前时机无法走这条路线"}
					}
				}
			}
			worldMap.Routes = append(worldMap.Routes, visibleRoute)
		}
	}
	return worldMap
}

func (s *Session) visibleRouteBlockers(state *domain.WorldState, route domain.Route) []string {
	blockers := make([]string, 0, 2)
	if route.RequiredItem != "" && state.Player.Items[route.RequiredItem] <= 0 {
		name := route.RequiredItem
		if item, ok := s.bundle.Items[route.RequiredItem]; ok {
			name = item.Name
		}
		blockers = append(blockers, "缺少"+name)
	}
	if route.RequiredFlag != "" && !state.WorldFlag(route.RequiredFlag) {
		blockers = append(blockers, routeFlagLabel(route.RequiredFlag))
	}
	return blockers
}

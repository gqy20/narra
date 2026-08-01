package app

import "fantu/internal/domain"

func (s *Session) preparationSummary(state *domain.WorldState) PreparationSummary {
	contest := s.bundle.Scenario.Contest
	summary := PreparationSummary{
		ScoreSources: make([]PreparationFactor, 0, len(contest.ScoreResources)+1),
		Conditions:   make([]PreparationFactor, 0, 2),
	}
	for _, resource := range contest.ScoreResources {
		value := state.Player.Resources[resource]
		status := "当前尚未建立"
		if value > 0 {
			status = "会计入你自己的争夺准备"
		}
		summary.ScoreSources = append(summary.ScoreSources, PreparationFactor{
			Key: resource, Label: resourceName(resource), Value: value, Status: status, Ready: value > 0,
		})
	}
	if contest.PreparationFlag != "" && state.ActorFlag(state.Player.ID, contest.PreparationFlag) {
		summary.ScoreSources = append(summary.ScoreSources, PreparationFactor{
			Key: "prepared", Label: "额外筹备", Value: 1, Status: "已形成一项额外准备", Ready: true,
		})
	}

	itemName := contest.RequiredItemID
	if item, ok := s.bundle.Items[contest.RequiredItemID]; ok {
		itemName = item.Name
	}
	hasItem := contest.RequiredItemID == "" || state.Player.Items[contest.RequiredItemID] > 0
	itemStatus := "尚未备齐；没有它不能参与核心争夺"
	if hasItem {
		itemStatus = "已经备齐，可满足核心争夺条件"
	}
	summary.Conditions = append(summary.Conditions, PreparationFactor{
		Key: "required_item", Label: itemName, Status: itemStatus, Ready: hasItem,
	})

	destination := s.visibleLocation(contest.LocationID).Name
	atDestination := state.Player.Location == contest.LocationID
	locationStatus := "尚未抵达；必须在结算前到达"
	if atDestination {
		locationStatus = "已经抵达核心争夺地点"
	}
	summary.Conditions = append(summary.Conditions, PreparationFactor{
		Key: "location", Label: destination, Status: locationStatus, Ready: atDestination,
	})
	return summary
}

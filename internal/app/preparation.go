package app

import "fantu/internal/domain"

func (s *Session) preparationSummary(state *domain.WorldState) PreparationSummary {
	contest := s.bundle.Scenario.Contest
	const targetScore = 6
	summary := PreparationSummary{
		ScoreSources: make([]PreparationFactor, 0, len(contest.ScoreResources)+1),
		Conditions:   make([]PreparationFactor, 0, 2),
		TargetScore:  targetScore,
		Eligible:     true,
	}
	for _, resource := range contest.ScoreResources {
		value := state.Player.Resources[resource]
		summary.TotalScore += value
		status := "当前尚未建立"
		if value > 0 {
			status = "会计入你自己的争夺准备"
		}
		summary.ScoreSources = append(summary.ScoreSources, PreparationFactor{
			Key: resource, Label: resourceName(resource), Value: value, Status: status, Ready: value > 0,
		})
	}
	if contest.PreparationFlag != "" && state.ActorFlag(state.Player.ID, contest.PreparationFlag) {
		summary.TotalScore++
		summary.ScoreSources = append(summary.ScoreSources, PreparationFactor{
			Key: "prepared", Label: "额外筹备", Value: 1, Status: "已形成一项额外准备", Ready: true,
		})
	}

	itemName := contest.RequiredItemID
	if item, ok := s.bundle.Items[contest.RequiredItemID]; ok {
		itemName = item.Name
	}
	hasItem := contest.RequiredItemID == "" || state.Player.Items[contest.RequiredItemID] > 0
	summary.Eligible = summary.Eligible && hasItem
	itemStatus := "尚未备齐；没有它不能参与核心争夺"
	if hasItem {
		itemStatus = "已经备齐，可满足核心争夺条件"
	}
	summary.Conditions = append(summary.Conditions, PreparationFactor{
		Key: "required_item", Label: itemName, Status: itemStatus, Ready: hasItem,
	})

	destination := s.visibleLocation(contest.LocationID).Name
	atDestination := state.Player.Location == contest.LocationID
	summary.Eligible = summary.Eligible && atDestination
	locationStatus := "尚未抵达；必须在结算前到达"
	if atDestination {
		locationStatus = "已经抵达核心争夺地点"
	}
	summary.Conditions = append(summary.Conditions, PreparationFactor{
		Key: "location", Label: destination, Status: locationStatus, Ready: atDestination,
	})
	switch {
	case summary.TotalScore >= targetScore+1:
		summary.Rating = "优势明显"
		summary.RatingDetail = "综合准备已经超过已知争夺基线；满足入谷条件后，有较大把握正面争夺。"
	case summary.TotalScore >= targetScore:
		summary.Rating = "具备竞争力"
		summary.RatingDetail = "综合准备达到已知争夺基线；同分时仍可能受对手行动与伤势影响。"
	case summary.TotalScore >= targetScore-2:
		summary.Rating = "胜算偏低"
		summary.RatingDetail = "已经有部分准备，但距离稳定参与正面争夺仍有差距。"
	default:
		summary.Rating = "明显不足"
		summary.RatingDetail = "即使进入内谷，目前也很难压过主要争夺者。"
	}
	if !summary.Eligible {
		summary.RatingDetail += " 当前还没有同时满足丹药与抵达条件。"
	}
	return summary
}

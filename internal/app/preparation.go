package app

import "narra/internal/domain"

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
		status := s.uiText("preparation_resource_empty")
		if value > 0 {
			status = s.uiText("preparation_resource_ready")
		}
		summary.ScoreSources = append(summary.ScoreSources, PreparationFactor{
			Key: resource, Label: s.resourceName(resource), Value: value, Status: status, Ready: value > 0,
		})
	}
	if contest.PreparationFlag != "" && state.ActorFlag(state.Player.ID, contest.PreparationFlag) {
		summary.TotalScore++
		summary.ScoreSources = append(summary.ScoreSources, PreparationFactor{
			Key: "prepared", Label: s.uiText("preparation_extra_label"), Value: 1, Status: s.uiText("preparation_extra_ready"), Ready: true,
		})
	}

	if contest.RequiredItemID != "" {
		itemName := contest.RequiredItemID
		if item, ok := s.bundle.Items[contest.RequiredItemID]; ok {
			itemName = item.Name
		}
		hasItem := state.Player.Items[contest.RequiredItemID] > 0
		summary.Eligible = summary.Eligible && hasItem
		itemStatus := s.uiText("preparation_item_missing")
		if hasItem {
			itemStatus = s.uiText("preparation_item_ready")
		}
		summary.Conditions = append(summary.Conditions, PreparationFactor{
			Key: "required_item", Label: itemName, Status: itemStatus, Ready: hasItem,
		})
	}

	destination := s.visibleLocation(contest.LocationID).Name
	atDestination := state.Player.Location == contest.LocationID
	summary.Eligible = summary.Eligible && atDestination
	locationStatus := s.uiText("preparation_location_missing")
	if atDestination {
		locationStatus = s.uiText("preparation_location_ready")
	}
	summary.Conditions = append(summary.Conditions, PreparationFactor{
		Key: "location", Label: destination, Status: locationStatus, Ready: atDestination,
	})
	switch {
	case summary.TotalScore >= targetScore+1:
		summary.Rating = s.uiText("preparation_rating_strong")
		summary.RatingDetail = s.uiText("preparation_detail_strong")
	case summary.TotalScore >= targetScore:
		summary.Rating = s.uiText("preparation_rating_even")
		summary.RatingDetail = s.uiText("preparation_detail_even")
	case summary.TotalScore >= targetScore-2:
		summary.Rating = s.uiText("preparation_rating_low")
		summary.RatingDetail = s.uiText("preparation_detail_low")
	default:
		summary.Rating = s.uiText("preparation_rating_poor")
		summary.RatingDetail = s.uiText("preparation_detail_poor")
	}
	if !summary.Eligible {
		summary.RatingDetail += s.uiText("preparation_ineligible_suffix")
	}
	return summary
}

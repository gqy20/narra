package app

import (
	"fmt"
	"sort"
	"strings"

	"fantu/internal/domain"
)

func (s *Session) turnFeedback(actionID, actionName string, before, after *domain.WorldState) *TurnFeedback {
	feedback := &TurnFeedback{Day: after.Day, DaysAdvanced: after.Day - before.Day, ActionID: actionID, Action: actionName, Status: "completed"}
	storyFeedback, storySubjectID := s.storyFeedback(actionID, after)
	if storyFeedback != nil {
		feedback.Messages = append(feedback.Messages, storyFeedback.Messages...)
		feedback.Journal = append(feedback.Journal, storyFeedback.Journal...)
	}
	if before.Phase != after.Phase && after.Phase != "" {
		feedback.Messages = append(feedback.Messages, s.uiText("feedback_phase_changed", "phase", after.Phase))
	}

	if after.Player.Pending != nil {
		feedback.Status = "started"
		if before.Player.Pending != nil {
			feedback.Status = "progressing"
		}
		feedback.Messages = append(feedback.Messages,
			s.uiText("feedback_action_progress", "action", after.Player.Pending.Intent.Strategy.Description, "day", intText(after.Player.Pending.CompleteDay)))
	} else if before.Player.Pending != nil {
		feedback.Messages = append(feedback.Messages, s.uiText("feedback_action_completed"))
	}

	if before.Player.Location != after.Player.Location {
		feedback.Messages = append(feedback.Messages, s.uiText("feedback_arrived", "name", s.visibleLocation(after.Player.Location).Name))
	}
	if before.Player.Location == after.Player.Location {
		feedback.Messages = append(feedback.Messages, s.visibleActorChanges(before, after)...)
	}
	if before.Player.Injury != after.Player.Injury {
		feedback.Messages = append(feedback.Messages, s.uiText("feedback_injury_changed", "before", intText(before.Player.Injury), "after", intText(after.Player.Injury)))
	}
	feedback.Messages = append(feedback.Messages, s.resourceChanges(before.Player.Resources, after.Player.Resources)...)
	feedback.Messages = append(feedback.Messages, s.itemChanges(before.Player.Items, after.Player.Items)...)
	feedback.Messages = append(feedback.Messages, s.beliefChanges(before.Player.Beliefs, after.Player.Beliefs)...)

	for _, event := range after.Events[len(before.Events):] {
		if event.ActorID == "world" || event.TargetID == after.Player.ID {
			feedback.Messages = append(feedback.Messages, event.Description)
		} else if event.ActorID == after.Player.ID && event.ActionID == s.bundle.Rules.Player.ShareInformation.ActionID {
			feedback.Messages = append(feedback.Messages, s.uiText("feedback_information_delivered", "name", s.actorName(after, event.TargetID)))
			feedback.Messages = append(feedback.Messages, s.uiText("feedback_information_pending"))
		}
	}
	if before.Outcome != after.Outcome && after.Outcome != "" {
		feedback.Messages = append(feedback.Messages, s.uiText("feedback_outcome", "outcome", visibleOutcome(after.Outcome)))
	}
	feedback.Influence = s.visibleInfluence(after, after.Decisions[len(before.Decisions):], false)
	if len(feedback.Messages) == 0 {
		if actionID == "wait" {
			feedback.Messages = append(feedback.Messages, quietWaitMessage)
		} else {
			feedback.Messages = append(feedback.Messages, s.uiText("feedback_settled", "action", actionName))
		}
	}
	feedback.Messages = uniqueStrings(feedback.Messages)
	if storyFeedback != nil {
		feedback.Presentation = &PresentationCue{Kind: storyFeedback.Presentation.Kind, Intensity: storyFeedback.Presentation.Intensity, SubjectID: storySubjectID}
	} else {
		feedback.Presentation = s.presentationCue(actionID, before, after)
	}
	return feedback
}

func (s *Session) presentationCue(actionID string, before, after *domain.WorldState) *PresentationCue {
	if before.Player.Location != after.Player.Location {
		return &PresentationCue{Kind: "travel", Intensity: 2, SubjectID: after.Player.Location}
	}
	changedFacts := make([]string, 0)
	for factID, belief := range after.Player.Beliefs {
		previous, known := before.Player.Beliefs[factID]
		if !known || previous.Confidence != belief.Confidence || previous.Claim != belief.Claim {
			changedFacts = append(changedFacts, factID)
		}
	}
	if len(changedFacts) > 0 {
		sort.Strings(changedFacts)
		return &PresentationCue{Kind: "reveal", Intensity: 2, SubjectID: changedFacts[0]}
	}
	if after.Player.Injury > before.Player.Injury {
		return &PresentationCue{Kind: "danger", Intensity: 3, SubjectID: after.Player.ID}
	}
	parts := strings.Split(actionID, ":")
	kind := parts[0]
	subjectID := ""
	if len(parts) > 1 {
		subjectID = parts[1]
	}
	switch kind {
	case "verify":
		if after.Player.Pending != nil {
			return &PresentationCue{Kind: "focus", Intensity: 1, SubjectID: subjectID}
		}
		return &PresentationCue{Kind: "reveal", Intensity: 2, SubjectID: subjectID}
	case "tell":
		return &PresentationCue{Kind: "actor_focus", Intensity: 1, SubjectID: subjectID}
	case "buy":
		return &PresentationCue{Kind: "acquire", Intensity: 1, SubjectID: subjectID}
	case "heal":
		return &PresentationCue{Kind: "recovery", Intensity: 1, SubjectID: after.Player.ID}
	case "cultivate":
		return &PresentationCue{Kind: "focus", Intensity: 1, SubjectID: after.Player.ID}
	default:
		return &PresentationCue{Kind: "time", Intensity: 1}
	}
}

func (s *Session) resourceChanges(before, after map[string]int) []string {
	keys := make([]string, 0)
	for key, value := range after {
		if before[key] != value {
			keys = append(keys, key)
		}
	}
	sort.Strings(keys)
	result := make([]string, 0, len(keys))
	for _, key := range keys {
		delta := after[key] - before[key]
		result = append(result, s.uiText("feedback_resource_changed", "resource", s.resourceName(key), "delta", fmt.Sprintf("%+d", delta), "value", intText(after[key])))
	}
	return result
}

func (s *Session) itemChanges(before, after map[string]int) []string {
	keys := make([]string, 0)
	for key, value := range after {
		if before[key] != value {
			keys = append(keys, key)
		}
	}
	for key, value := range before {
		if _, exists := after[key]; !exists && value != 0 {
			keys = append(keys, key)
		}
	}
	sort.Strings(keys)
	result := make([]string, 0, len(keys))
	for _, key := range keys {
		name := key
		if item, ok := s.bundle.Items[key]; ok {
			name = item.Name
		}
		delta := after[key] - before[key]
		result = append(result, s.uiText("feedback_item_changed", "name", name, "delta", fmt.Sprintf("%+d", delta), "value", intText(after[key])))
	}
	return result
}

func (s *Session) beliefChanges(before, after map[string]domain.Belief) []string {
	keys := make([]string, 0)
	for key, belief := range after {
		previous, existed := before[key]
		if !existed || previous.Confidence != belief.Confidence || previous.Claim != belief.Claim {
			keys = append(keys, key)
		}
	}
	sort.Strings(keys)
	result := make([]string, 0, len(keys))
	for _, key := range keys {
		belief := after[key]
		result = append(result, s.uiText("feedback_belief_changed", "confidence", s.confidenceText(belief.Confidence), "claim", belief.Claim))
	}
	return result
}

func (s *Session) guidance(state *domain.WorldState, actions []AvailableAction) []string {
	if state.Outcome != "" {
		return []string{s.uiText("guidance_outcome_settled")}
	}
	if state.Player.Pending != nil {
		return []string{s.uiText("guidance_pending", "day", intText(state.Player.Pending.CompleteDay))}
	}

	available := make(map[string]bool, len(actions))
	for _, action := range actions {
		available[action.ID] = true
	}
	var result []string
	rumoredFactID := s.bundle.Scenario.Contest.RumoredDateFactID
	if belief, ok := state.Player.Beliefs[rumoredFactID]; rumoredFactID != "" && ok && belief.Confidence < 3 && available["verify:"+rumoredFactID] {
		result = append(result, s.uiText("guidance_verify_date"))
	}
	requiredItemID := s.bundle.Scenario.Contest.RequiredItemID
	if requiredItemID != "" && state.Player.Items[requiredItemID] == 0 {
		itemName := requiredItemID
		if item, ok := s.bundle.Items[requiredItemID]; ok {
			itemName = item.Name
		}
		marketOpen := false
		for _, market := range state.Markets {
			if market.Stock[requiredItemID] > 0 && (market.BlockadeFlag == "" || !state.WorldFlag(market.BlockadeFlag)) {
				marketOpen = true
				break
			}
		}
		if marketOpen {
			result = append(result, s.uiText("guidance_item_market", "name", itemName))
		} else {
			message := s.uiText("guidance_item_missing", "name", itemName)
			verifiedFactID := s.bundle.Scenario.Contest.VerifiedDateFactID
			if belief, ok := state.Player.Beliefs[verifiedFactID]; verifiedFactID != "" && ok && belief.Confidence >= 3 {
				message = s.uiText("guidance_verified_item_missing", "name", itemName)
			}
			result = append(result, message)
		}
	}
	if s.lastTurn != nil && strings.HasPrefix(s.lastTurn.ActionID, "tell:") {
		result = append(result, s.uiText("guidance_information_sent"))
	}
	if len(result) == 0 {
		result = append(result, s.uiText("guidance_default"))
	}
	return result
}

func (s *Session) endingSummary(state *domain.WorldState) *EndingSummary {
	ending := &EndingSummary{Outcome: visibleOutcome(state.Outcome)}
	ending.PlayerConsequences = s.playerConsequences(state)
	ending.Review = s.endingReview(state)
	counts := make(map[string]int)
	for _, actionID := range s.history {
		if strings.HasPrefix(actionID, "wait") {
			continue
		}
		category := actionID
		if index := strings.IndexByte(category, ':'); index >= 0 {
			category = category[:index]
		}
		counts[category]++
	}
	ending.Highlights = append(ending.Highlights,
		s.uiText("ending_metrics", "day", intText(state.Day), "decisions", intText(s.metrics.DecisionInputs), "active", intText(s.metrics.ActiveActions), "waits", intText(s.metrics.WaitActions)))
	for _, entry := range []struct {
		key  string
		text string
	}{{"verify", s.uiText("ending_action_verify")}, {"tell", s.uiText("ending_action_tell")}, {"route", s.uiText("ending_action_route")}, {"buy", s.uiText("ending_action_buy")}, {"move", s.uiText("ending_action_move")}, {"cultivate", s.uiText("ending_action_growth")}, {"heal", s.uiText("ending_action_recovery")}} {
		if counts[entry.key] > 0 {
			ending.Highlights = append(ending.Highlights, s.uiText("ending_action_count", "action", entry.text, "count", intText(counts[entry.key])))
		}
	}
	resourceSummary := make([]string, 0, len(s.bundle.Presentation.Resources))
	for _, resource := range s.bundle.Presentation.Resources {
		resourceSummary = append(resourceSummary, fmt.Sprintf("%s %d", resource.Label, state.Player.Resources[resource.ID]))
	}
	status := s.uiText("ending_status", "location", s.visibleLocation(state.Player.Location).Name, "injury", intText(state.Player.Injury))
	if len(resourceSummary) > 0 {
		status += "，" + strings.Join(resourceSummary, "，")
	}
	ending.Highlights = append(ending.Highlights, status+"。")
	ending.Influence = s.visibleInfluence(state, state.Decisions, true)
	changedDecisions := 0
	for _, influence := range ending.Influence {
		changedDecisions += len(influence.Changes)
		for _, change := range influence.Changes {
			ending.ActorPlanChanges = append(ending.ActorPlanChanges, fmt.Sprintf(
				"第 %d 日，%s原本准备%s，后来改为%s。",
				change.Day, influence.ActorName, change.WithoutInformation, change.WithInformation,
			))
		}
	}
	ending.ActorPlanChanges = uniqueStrings(ending.ActorPlanChanges)
	if changedDecisions > 0 {
		ending.Highlights = append([]string{s.uiText("ending_influence", "count", intText(changedDecisions))}, ending.Highlights...)
	}
	return ending
}

func (s *Session) endingReview(state *domain.WorldState) []string {
	contest := s.bundle.Scenario.Contest
	player := state.Player
	result := make([]string, 0, 4)
	owner := state.Items[contest.ItemID]
	playerScore := 0
	for _, resource := range contest.ScoreResources {
		playerScore += player.Resources[resource]
	}
	if contest.PreparationFlag != "" && state.ActorFlag(player.ID, contest.PreparationFlag) {
		playerScore++
	}
	if owner == player.ID {
		result = append(result, s.uiText("ending_review_won", "score", intText(playerScore)))
	} else {
		if contest.RequiredItemID != "" && player.Items[contest.RequiredItemID] <= 0 {
			itemName := contest.RequiredItemID
			if item, ok := s.bundle.Items[contest.RequiredItemID]; ok {
				itemName = item.Name
			}
			result = append(result, s.uiText("ending_review_missing_item", "name", itemName))
		}
		if player.Location != contest.LocationID {
			result = append(result, s.uiText("ending_review_late", "day", intText(contest.Day), "name", s.visibleLocation(contest.LocationID).Name))
		}
		if len(result) == 0 {
			winnerScore := s.actorContestScore(state, owner)
			if winnerScore > playerScore {
				result = append(result, s.uiText("ending_review_lost", "score", intText(playerScore), "winner", s.actorName(state, owner), "winner_score", intText(winnerScore), "lead", intText(winnerScore-playerScore)))
			} else {
				result = append(result, s.uiText("ending_review_tie", "score", intText(playerScore)))
			}
		}
	}
	if s.metrics.ActiveActions == 0 {
		result = append(result, s.uiText("ending_review_passive"))
		result = append(result, s.uiText("ending_review_next"))
	}
	return result
}

func (s *Session) actorContestScore(state *domain.WorldState, actorID string) int {
	contest := s.bundle.Scenario.Contest
	if actorID == state.Player.ID {
		score := 0
		for _, resource := range contest.ScoreResources {
			score += state.Player.Resources[resource]
		}
		if contest.PreparationFlag != "" && state.ActorFlag(actorID, contest.PreparationFlag) {
			score++
		}
		return score
	}
	actor, ok := state.NPCs[actorID]
	if !ok {
		return 0
	}
	score := -actor.Injury
	for _, resource := range contest.ScoreResources {
		score += actor.Resources[resource]
	}
	if contest.PreparationFlag != "" && state.ActorFlag(actorID, contest.PreparationFlag) {
		score++
	}
	return score
}

func (s *Session) playerConsequences(state *domain.WorldState) []string {
	return s.storyConsequences(state)
}

func confidenceLabel(confidence int) string {
	switch {
	case confidence >= 3:
		return "已核实"
	case confidence == 2:
		return "较可信"
	default:
		return "未经核实"
	}
}

func visibleOutcome(outcome string) string {
	marker := " 以准备值 "
	start := strings.Index(outcome, marker)
	if start < 0 {
		return outcome
	}
	rest := outcome[start+len(marker):]
	end := strings.Index(rest, " 取得")
	if end < 0 {
		return outcome
	}
	return outcome[:start] + " 最终取得" + rest[end+len(" 取得"):]
}

type visibleDelivery struct {
	eventID   string
	actorID   string
	actorName string
	factID    string
	factClaim string
	day       int
}

func (s *Session) visibleInfluence(state *domain.WorldState, decisions []domain.DecisionRecord, includeDeliveries bool) []VisibleInfluence {
	deliveries := make(map[string]visibleDelivery)
	orderedDeliveryIDs := make([]string, 0)
	for _, event := range state.Events {
		if event.ActorID != state.Player.ID || event.ActionID != s.bundle.Rules.Player.ShareInformation.ActionID {
			continue
		}
		for _, effect := range event.Effects {
			if effect.Type != "set_belief" {
				continue
			}
			claim := effect.Claim
			if belief, ok := state.Player.Beliefs[effect.FactID]; claim == "" && ok {
				claim = belief.Claim
			}
			deliveries[event.ID] = visibleDelivery{
				eventID: event.ID, actorID: event.TargetID, actorName: s.actorName(state, event.TargetID),
				factID: effect.FactID, factClaim: claim, day: event.Day,
			}
			orderedDeliveryIDs = append(orderedDeliveryIDs, event.ID)
			break
		}
	}

	result := make([]VisibleInfluence, 0)
	indexes := make(map[string]int)
	if includeDeliveries {
		for _, eventID := range orderedDeliveryIDs {
			delivery := deliveries[eventID]
			indexes[eventID] = len(result)
			result = append(result, VisibleInfluence{
				ActorName: delivery.actorName, FactID: delivery.factID,
				FactClaim: delivery.factClaim, DeliveredDay: delivery.day,
			})
		}
	}
	for _, decision := range decisions {
		for _, counterfactual := range decision.Counterfactuals {
			delivery, ok := deliveries[counterfactual.TriggerEventID]
			if counterfactual.Kind != "belief" || !counterfactual.Changed || !ok {
				continue
			}
			index, exists := indexes[counterfactual.TriggerEventID]
			if !exists {
				index = len(result)
				indexes[counterfactual.TriggerEventID] = index
				result = append(result, VisibleInfluence{
					ActorName: delivery.actorName, FactID: delivery.factID,
					FactClaim: delivery.factClaim, DeliveredDay: delivery.day,
				})
			}
			change := VisibleDecisionChange{
				Day:                decision.Day,
				WithoutInformation: s.strategyDescription(decision.ActorID, counterfactual.AlternativeStrategyID, decision.Choices, "其他安排"),
				WithInformation:    s.strategyDescription(decision.ActorID, counterfactual.OriginalStrategyID, decision.Choices, "新的安排"),
			}
			result[index].Changes = appendUniqueChange(result[index].Changes, change)
		}
	}
	for index := range result {
		influence := &result[index]
		if len(influence.Changes) > 0 {
			latest := influence.Changes[len(influence.Changes)-1]
			influence.Stage = "changed"
			influence.StageLabel = "已改变公开行动"
			influence.Summary = fmt.Sprintf("第 %d 日 · %s", latest.Day, latest.WithInformation)
			continue
		}
		influence.Stage = "delivered"
		influence.StageLabel = "已送达 · 等待公开回响"
		influence.Summary = "尚未观察到由这条消息引起的公开行动变化"
	}
	return result
}

func (s *Session) strategyDescription(actorID, strategyID string, choices []domain.RankedChoice, fallback string) string {
	if strategyID == "" {
		return "暂不采取相关行动"
	}
	for _, choice := range choices {
		if choice.StrategyID == strategyID && choice.Description != "" {
			return choice.Description
		}
	}
	for _, npc := range s.bundle.NPCs {
		if npc.ID != actorID {
			continue
		}
		for _, strategy := range npc.Strategies {
			if strategy.ID == strategyID && strategy.Description != "" {
				return strategy.Description
			}
		}
	}
	return fallback
}

func appendUniqueChange(changes []VisibleDecisionChange, candidate VisibleDecisionChange) []VisibleDecisionChange {
	for _, change := range changes {
		if change == candidate {
			return changes
		}
	}
	return append(changes, candidate)
}

func (s *Session) resourceName(key string) string {
	for _, resource := range s.bundle.Presentation.Resources {
		if resource.ID == key {
			return resource.Label
		}
	}
	return key
}

func (s *Session) actorName(state *domain.WorldState, actorID string) string {
	if actorID == state.Player.ID {
		return state.Player.Name
	}
	if npc, ok := state.NPCs[actorID]; ok {
		return npc.Name
	}
	return actorID
}

func (s *Session) visibleActorChanges(before, after *domain.WorldState) []string {
	beforeVisible := make(map[string]VisibleActor)
	for _, actor := range s.visibleActors(before) {
		beforeVisible[actor.ID] = actor
	}
	afterVisible := make(map[string]VisibleActor)
	for _, actor := range s.visibleActors(after) {
		afterVisible[actor.ID] = actor
	}
	var arrived, left []string
	for id, actor := range afterVisible {
		if _, existed := beforeVisible[id]; !existed {
			arrived = append(arrived, actor.Name)
		}
	}
	for id, actor := range beforeVisible {
		if _, remains := afterVisible[id]; !remains {
			left = append(left, actor.Name)
		}
	}
	sort.Strings(arrived)
	sort.Strings(left)
	var result []string
	if len(arrived) > 0 {
		result = append(result, strings.Join(arrived, "、")+"来到此地。")
	}
	if len(left) > 0 {
		result = append(result, strings.Join(left, "、")+"离开此地。")
	}
	return result
}

func cloneTurnFeedback(source *TurnFeedback) *TurnFeedback {
	if source == nil {
		return nil
	}
	clone := *source
	clone.Messages = append([]string(nil), source.Messages...)
	clone.Influence = cloneInfluences(source.Influence)
	return &clone
}

func cloneInfluences(source []VisibleInfluence) []VisibleInfluence {
	result := append([]VisibleInfluence(nil), source...)
	for index := range result {
		result[index].Changes = append([]VisibleDecisionChange(nil), source[index].Changes...)
	}
	return result
}

func uniqueStrings(values []string) []string {
	seen := make(map[string]bool, len(values))
	result := make([]string, 0, len(values))
	for _, value := range values {
		if value != "" && !seen[value] {
			seen[value] = true
			result = append(result, value)
		}
	}
	return result
}

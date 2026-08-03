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
		feedback.Messages = append(feedback.Messages, "局势进入“"+after.Phase+"”阶段。")
	}

	if after.Player.Pending != nil {
		feedback.Status = "started"
		if before.Player.Pending != nil {
			feedback.Status = "progressing"
		}
		feedback.Messages = append(feedback.Messages,
			fmt.Sprintf("%s仍在进行，预计第 %d 天完成。", after.Player.Pending.Intent.Strategy.Description, after.Player.Pending.CompleteDay))
	} else if before.Player.Pending != nil {
		feedback.Messages = append(feedback.Messages, "持续行动已经完成。")
	}

	if before.Player.Location != after.Player.Location {
		feedback.Messages = append(feedback.Messages, "抵达"+s.visibleLocation(after.Player.Location).Name+"。")
	}
	if before.Player.Location == after.Player.Location {
		feedback.Messages = append(feedback.Messages, s.visibleActorChanges(before, after)...)
	}
	if before.Player.Injury != after.Player.Injury {
		feedback.Messages = append(feedback.Messages,
			fmt.Sprintf("伤势由 %d 变为 %d。", before.Player.Injury, after.Player.Injury))
	}
	feedback.Messages = append(feedback.Messages, resourceChanges(before.Player.Resources, after.Player.Resources)...)
	feedback.Messages = append(feedback.Messages, s.itemChanges(before.Player.Items, after.Player.Items)...)
	feedback.Messages = append(feedback.Messages, beliefChanges(before.Player.Beliefs, after.Player.Beliefs)...)

	for _, event := range after.Events[len(before.Events):] {
		if event.ActorID == "world" || event.TargetID == after.Player.ID {
			feedback.Messages = append(feedback.Messages, event.Description)
		} else if event.ActorID == after.Player.ID && event.ActionID == "spread" {
			feedback.Messages = append(feedback.Messages, "情报已经送达"+s.actorName(after, event.TargetID)+"。")
			feedback.Messages = append(feedback.Messages, "对方是否改变行动，会在后续局势变化时显现。")
		}
	}
	if before.Outcome != after.Outcome && after.Outcome != "" {
		feedback.Messages = append(feedback.Messages, "核心争夺结果："+visibleOutcome(after.Outcome))
	}
	feedback.Influence = s.visibleInfluence(after, after.Decisions[len(before.Decisions):], false)
	if len(feedback.Messages) == 0 {
		if actionID == "wait" {
			feedback.Messages = append(feedback.Messages, quietWaitMessage)
		} else {
			feedback.Messages = append(feedback.Messages, actionName+"已经结算。")
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

func resourceChanges(before, after map[string]int) []string {
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
		result = append(result, fmt.Sprintf("%s %+d，现有 %d。", resourceName(key), delta, after[key]))
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
		result = append(result, fmt.Sprintf("物品 %s %+d，现有 %d。", name, delta, after[key]))
	}
	return result
}

func beliefChanges(before, after map[string]domain.Belief) []string {
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
		result = append(result, fmt.Sprintf("线索更新为%s：%s", confidenceLabel(belief.Confidence), belief.Claim))
	}
	return result
}

func (s *Session) guidance(state *domain.WorldState, actions []AvailableAction) []string {
	if state.Outcome != "" {
		return []string{"核心争夺已经结算；你可以继续观察局势余波直到场景结束。"}
	}
	if state.Player.Pending != nil {
		return []string{fmt.Sprintf("当前行动还需等待到第 %d 天完成。", state.Player.Pending.CompleteDay)}
	}

	available := make(map[string]bool, len(actions))
	for _, action := range actions {
		available[action.ID] = true
	}
	var result []string
	if belief, ok := state.Player.Beliefs["F02"]; ok && belief.Confidence < 3 && available["verify:F02"] {
		result = append(result, "第24天成熟目前只是传闻，核验后再据此安排路线更稳妥。")
	}
	if state.Player.Items["antidote"] == 0 {
		marketOpen := false
		for _, market := range state.Markets {
			if market.Stock["antidote"] > 0 && (market.BlockadeFlag == "" || !state.WorldFlag(market.BlockadeFlag)) {
				marketOpen = true
				break
			}
		}
		switch {
		case available["buy:M01:antidote"]:
			result = append(result, "解瘴丹目前仍可购买；进入黑风谷需要它，市场供应可能随局势变化。")
		case marketOpen:
			result = append(result, "白石坊市仍有解瘴丹出售；若想亲自入谷，需要先返回坊市购买。")
		default:
			if available["recover:N06:antidote"] {
				result = append(result, "坊市已经封锁，亲自入谷路线受阻；可把已核实的成熟日期交给苏晚照，换取一枚解瘴丹并恢复路线。")
			} else if belief, ok := state.Player.Beliefs["F01"]; ok && belief.Confidence >= 3 {
				result = append(result, "坊市已经封锁，亲自入谷路线受阻；带着已核实的成熟日期前往青岚门驻地，可向苏晚照换取一枚解瘴丹。")
			} else {
				result = append(result, "坊市已经封锁，亲自入谷路线受阻；核实成熟日期后前往青岚门驻地，可尝试以情报换取解瘴丹；也可继续通过传播影响最终归属。")
			}
		}
	}
	if s.lastTurn != nil && strings.HasPrefix(s.lastTurn.ActionID, "tell:") {
		result = append(result, "情报已经送达；等待局势变化可以观察它是否改变对方的选择。")
	}
	if len(result) == 0 {
		result = append(result, "没有必须执行的行动；根据已知线索决定调查、交涉、准备或等待。")
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
		fmt.Sprintf("局势推进到第 %d 天；你做出 %d 次决策，其中主动行动 %d 次、推进时间 %d 次。", state.Day, s.metrics.DecisionInputs, s.metrics.ActiveActions, s.metrics.WaitActions))
	for _, entry := range []struct {
		key  string
		text string
	}{{"verify", "核验情报"}, {"tell", "分享情报"}, {"route", "回应路线考验"}, {"buy", "购买物品"}, {"move", "移动"}, {"cultivate", "修炼"}, {"heal", "疗伤"}} {
		if counts[entry.key] > 0 {
			ending.Highlights = append(ending.Highlights, fmt.Sprintf("%s %d 次。", entry.text, counts[entry.key]))
		}
	}
	ending.Highlights = append(ending.Highlights,
		fmt.Sprintf("终局时你位于%s，战力 %d，伤势 %d。", s.visibleLocation(state.Player.Location).Name, state.Player.Resources["combat"], state.Player.Injury))
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
		ending.Highlights = append([]string{fmt.Sprintf("你传递的消息改变了 %d 个关键选择，并影响了最终归属。", changedDecisions)}, ending.Highlights...)
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
		result = append(result, fmt.Sprintf("你满足了丹药与抵达条件，并以 %d 点综合准备赢得正面争夺。", playerScore))
	} else {
		if contest.RequiredItemID != "" && player.Items[contest.RequiredItemID] <= 0 {
			result = append(result, "你在结算时没有解瘴丹，因此没有取得核心争夺资格。")
		}
		if player.Location != contest.LocationID {
			result = append(result, "你没有在第 21 日前抵达黑风谷内谷，因此没有进入最终候选。")
		}
		if len(result) == 0 {
			winnerScore := s.actorContestScore(state, owner)
			if winnerScore > playerScore {
				result = append(result, fmt.Sprintf("你具备争夺资格，但综合准备为 %d；胜者%s达到 %d，领先 %d 点。", playerScore, s.actorName(state, owner), winnerScore, winnerScore-playerScore))
			} else {
				result = append(result, fmt.Sprintf("你具备争夺资格，综合准备为 %d；同分时先完成局势占位的争夺者取得归属。", playerScore))
			}
		}
	}
	if s.metrics.ActiveActions == 0 {
		result = append(result, "本局没有进行主动行动；等待让你跳过了平静日，也同时放弃了核验、备药、交涉和修炼窗口。")
		result = append(result, "下一局可先核验成熟日期或购买解瘴丹，再决定亲自争夺、扶持盟友或锁定交易收益。")
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
		if event.ActorID != state.Player.ID || event.ActionID != "spread" {
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

func resourceName(key string) string {
	switch key {
	case "combat":
		return "战力"
	case "support":
		return "助力"
	case "spirit_stones":
		return "灵石"
	case "credit":
		return "信誉"
	default:
		return key
	}
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

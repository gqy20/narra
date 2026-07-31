package app

import (
	"fmt"
	"sort"
	"strings"

	"fantu/internal/domain"
)

func (s *Session) turnFeedback(actionID, actionName string, before, after *domain.WorldState) *TurnFeedback {
	feedback := &TurnFeedback{Day: after.Day, ActionID: actionID, Action: actionName, Status: "completed"}

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
		}
	}
	if before.Outcome != after.Outcome && after.Outcome != "" {
		feedback.Messages = append(feedback.Messages, "核心争夺结果："+after.Outcome)
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
	return feedback
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
		result = append(result, fmt.Sprintf("线索更新为可信度 %d：%s", belief.Confidence, belief.Claim))
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
	if state.Player.Items["antidote"] == 0 && available["buy:M01:antidote"] {
		result = append(result, "解瘴丹目前仍可购买；进入黑风谷需要它，市场供应可能随局势变化。")
	}
	if (state.Player.Location == "L01" || state.Player.Location == "L02" || state.Player.Location == "L03") && !available["move:L04"] {
		result = append(result, "通往黑风谷的条件尚未齐备；路线开放与解瘴丹都会影响通行。")
	}
	if len(result) == 0 {
		result = append(result, "没有必须执行的行动；根据已知线索决定调查、交涉、准备或等待。")
	}
	return result
}

func (s *Session) endingSummary(state *domain.WorldState) *EndingSummary {
	ending := &EndingSummary{Outcome: state.Outcome}
	counts := make(map[string]int)
	waits := 0
	for _, actionID := range s.history {
		if actionID == "wait" {
			waits++
			continue
		}
		category := actionID
		if index := strings.IndexByte(category, ':'); index >= 0 {
			category = category[:index]
		}
		counts[category]++
	}
	ending.Highlights = append(ending.Highlights,
		fmt.Sprintf("你推进了 %d 天，其中主动行动 %d 次、等待 %d 天。", len(s.history), len(s.history)-waits, waits))
	for _, entry := range []struct {
		key  string
		text string
	}{{"verify", "核验情报"}, {"tell", "分享情报"}, {"buy", "购买物品"}, {"move", "移动"}, {"cultivate", "修炼"}, {"heal", "疗伤"}} {
		if counts[entry.key] > 0 {
			ending.Highlights = append(ending.Highlights, fmt.Sprintf("%s %d 次。", entry.text, counts[entry.key]))
		}
	}
	ending.Highlights = append(ending.Highlights,
		fmt.Sprintf("终局时你位于%s，战力 %d，伤势 %d。", s.visibleLocation(state.Player.Location).Name, state.Player.Resources["combat"], state.Player.Injury))
	ending.Influence = s.visibleInfluence(state, state.Decisions, true)
	return ending
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
		return "支援"
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

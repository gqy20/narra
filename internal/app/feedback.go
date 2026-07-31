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
	if len(feedback.Messages) == 0 {
		if actionID == "wait" {
			feedback.Messages = append(feedback.Messages, "一天过去，局势继续发展。")
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
		result = append(result, fmt.Sprintf("资源 %s %+d，现有 %d。", key, delta, after[key]))
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
		result = append(result, fmt.Sprintf("线索 %s 更新为可信度 %d：%s", key, belief.Confidence, belief.Claim))
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
	ending.Influence = s.visibleInfluence(state)
	return ending
}

func (s *Session) visibleInfluence(state *domain.WorldState) []string {
	playerEvents := make(map[string]bool)
	var result []string
	for _, event := range state.Events {
		if event.ActorID == state.Player.ID {
			playerEvents[event.ID] = true
			if event.ActionID == "spread" {
				for _, effect := range event.Effects {
					if effect.Type == "set_belief" {
						result = append(result, fmt.Sprintf("第 %d 天，你把 %s 告诉了%s；该情报已进入其认知。", event.Day, effect.FactID, s.actorName(state, event.TargetID)))
					}
				}
			}
		}
	}
	for _, decision := range state.Decisions {
		for _, counterfactual := range decision.Counterfactuals {
			if counterfactual.Kind == "belief" && counterfactual.Changed && playerEvents[counterfactual.TriggerEventID] {
				result = append(result, fmt.Sprintf("第 %d 天，你提供的情报改变了%s的首选行动。", decision.Day, decision.ActorName))
				break
			}
		}
	}
	return uniqueStrings(result)
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
	return &clone
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

package app

import (
	"fmt"
	"reflect"
	"sort"
	"strings"

	"fantu/internal/domain"
)

func (s *Session) advanceUntilDecision(before *domain.WorldState, actionID, actionName, mode string) (*domain.WorldState, *TurnFeedback, error) {
	current := before
	aggregate := &TurnFeedback{ActionID: actionID, Action: actionName, Status: "completed"}
	for current.Day < s.bundle.Scenario.Duration {
		next, err := s.engine.Step(nil)
		if err != nil {
			return current, nil, err
		}
		step := s.turnFeedback(actionID, actionName, current, next)
		aggregate.DaysAdvanced += step.DaysAdvanced
		if !isQuietStep(step) {
			for _, message := range step.Messages {
				if message != quietWaitMessage {
					aggregate.Messages = append(aggregate.Messages, message)
				}
			}
		}
		aggregate.Influence = mergeInfluences(aggregate.Influence, step.Influence)

		stop := false
		stopReason := ""
		switch {
		case next.Outcome != "":
			stop, stopReason = true, "核心争夺已经产生结果"
		case next.Day >= s.bundle.Scenario.Duration:
			stop, stopReason = true, "局势已经推进到本章末日"
		case len(step.Influence) > 0:
			stop, stopReason = true, "你送出的消息改变了人物的公开行动"
		case !reflect.DeepEqual(current.Player, next.Player):
			stop, stopReason = true, "你的状态、行装或正在进行的行动发生了变化"
		default:
			beforeOptions := s.actionOptions(current)
			afterOptions := s.actionOptions(next)
			if decisionSignature(beforeOptions) != decisionSignature(afterOptions) {
				stop = true
				if actionName := newlyAvailableActionName(beforeOptions, afterOptions); actionName != "" {
					stopReason = "新的选择出现：" + actionName
				} else {
					stopReason = "可执行的安排发生了变化"
				}
			} else if visibleActorSet(s.visibleActors(current)) != visibleActorSet(s.visibleActors(next)) {
				stop, stopReason = true, "眼前人物发生了变化"
			}
		}
		if stop && aggregate.StopReason == "" {
			aggregate.StopReason = stopReason
		}
		if !stop {
			aggregate.QuietDays += step.DaysAdvanced
		}
		current = next
		if stop {
			break
		}
	}

	aggregate.Day = current.Day
	if current.Player.Pending != nil {
		aggregate.Status = "progressing"
	}
	if len(aggregate.Messages) == 0 && len(aggregate.Influence) == 0 {
		aggregate.Messages = []string{fmt.Sprintf("已推进到第 %d 天，期间没有需要处理的变化。", current.Day)}
	}
	aggregate.Messages = uniqueStrings(aggregate.Messages)
	aggregate.Presentation = s.presentationCue(actionID, before, current)
	return current, aggregate, nil
}

func newlyAvailableActionName(before, after map[string]actionOption) string {
	ids := make([]string, 0)
	for id := range after {
		if strings.HasPrefix(id, "wait") {
			continue
		}
		if _, existed := before[id]; !existed {
			ids = append(ids, id)
		}
	}
	sort.Strings(ids)
	if len(ids) == 0 {
		return ""
	}
	return after[ids[0]].view.Name
}

func isQuietStep(feedback *TurnFeedback) bool {
	return len(feedback.Messages) == 1 && feedback.Messages[0] == quietWaitMessage && len(feedback.Influence) == 0
}

func decisionSignature(options map[string]actionOption) string {
	entries := make([]string, 0, len(options))
	for id, option := range options {
		if strings.HasPrefix(id, "wait") {
			continue
		}
		costKeys := make([]string, 0, len(option.view.Costs))
		for key := range option.view.Costs {
			costKeys = append(costKeys, key)
		}
		sort.Strings(costKeys)
		costs := make([]string, 0, len(costKeys))
		for _, key := range costKeys {
			costs = append(costs, fmt.Sprintf("%s=%d", key, option.view.Costs[key]))
		}
		entries = append(entries, fmt.Sprintf("%s|%s|%d|%s", id, option.view.Description, option.view.Duration, strings.Join(costs, ",")))
	}
	sort.Strings(entries)
	return strings.Join(entries, ";")
}

func visibleActorSet(actors []VisibleActor) string {
	ids := make([]string, 0, len(actors))
	for _, actor := range actors {
		ids = append(ids, actor.ID)
	}
	sort.Strings(ids)
	return strings.Join(ids, ",")
}

func mergeInfluences(target, source []VisibleInfluence) []VisibleInfluence {
	for _, candidate := range source {
		index := -1
		for current := range target {
			if target[current].ActorName == candidate.ActorName && target[current].FactID == candidate.FactID && target[current].DeliveredDay == candidate.DeliveredDay {
				index = current
				break
			}
		}
		if index < 0 {
			clone := candidate
			clone.Changes = append([]VisibleDecisionChange(nil), candidate.Changes...)
			target = append(target, clone)
			continue
		}
		for _, change := range candidate.Changes {
			target[index].Changes = appendUniqueChange(target[index].Changes, change)
		}
	}
	return target
}

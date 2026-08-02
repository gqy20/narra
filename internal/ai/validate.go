package ai

import (
	"fmt"
	"strings"
	"unicode/utf8"

	"fantu/internal/app"
)

var validEmotions = map[string]bool{"neutral": true, "alert": true, "troubled": true, "decisive": true}
var validDialogueActs = map[string]bool{"greet": true, "invite": true, "question": true, "warn": true, "refuse": true, "acknowledge": true}

func validateDialogue(snapshot app.DialogueSnapshot, draft *DialogueDraft) error {
	draft.Utterance = strings.TrimSpace(draft.Utterance)
	if draft.Utterance == "" || utf8.RuneCountInString(draft.Utterance) > 80 {
		return fmt.Errorf("dialogue utterance must contain 1 to 80 characters")
	}
	if !validEmotions[draft.Emotion] {
		return fmt.Errorf("invalid dialogue emotion %q", draft.Emotion)
	}
	if !validDialogueActs[draft.DialogueAct] {
		return fmt.Errorf("invalid dialogue act %q", draft.DialogueAct)
	}
	allowed := make(map[string]app.DialogueClaim, len(snapshot.AllowedClaims))
	for _, claim := range snapshot.AllowedClaims {
		allowed[claim.FactID] = claim
	}
	seen := make(map[string]bool, len(draft.ReferencedFacts))
	for _, factID := range draft.ReferencedFacts {
		claim, ok := allowed[factID]
		if !ok {
			return fmt.Errorf("dialogue references unavailable fact %q", factID)
		}
		if seen[factID] {
			return fmt.Errorf("dialogue references fact %q more than once", factID)
		}
		seen[factID] = true
		if claim.Confidence == "只是听说" && !containsAny(draft.Utterance, []string{"听说", "传闻", "据说", "尚未核实", "尚未证实", "真假", "若消息属实", "若此事属实", "若是真的", "是否属实"}) {
			return fmt.Errorf("dialogue states rumored fact %q without uncertainty", factID)
		}
	}
	allowedActions := make(map[string]bool, len(snapshot.AvailableActions))
	for _, action := range snapshot.AvailableActions {
		allowedActions[action.ID] = true
	}
	seenActions := make(map[string]bool, len(draft.SuggestedActions))
	for _, actionID := range draft.SuggestedActions {
		if !allowedActions[actionID] {
			return fmt.Errorf("dialogue suggests unavailable action %q", actionID)
		}
		if seenActions[actionID] {
			return fmt.Errorf("dialogue suggests action %q more than once", actionID)
		}
		seenActions[actionID] = true
	}
	lower := strings.ToLower(draft.Utterance)
	for _, forbidden := range []string{"world_flags", "actor_flags", "strategy_id", "score", "提示词", "系统字段"} {
		if strings.Contains(lower, forbidden) {
			return fmt.Errorf("dialogue contains internal term %q", forbidden)
		}
	}
	for _, unsupportedSelfAddress := range []string{"老夫", "贫道", "小老儿", "妾身"} {
		if strings.Contains(draft.Utterance, unsupportedSelfAddress) {
			return fmt.Errorf("dialogue uses unsupported self-address %q", unsupportedSelfAddress)
		}
	}
	return nil
}

func containsAny(value string, candidates []string) bool {
	for _, candidate := range candidates {
		if strings.Contains(value, candidate) {
			return true
		}
	}
	return false
}

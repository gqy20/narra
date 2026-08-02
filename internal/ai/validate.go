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
	allowed := make(map[string]bool, len(snapshot.AllowedClaims))
	for _, claim := range snapshot.AllowedClaims {
		allowed[claim.FactID] = true
	}
	seen := make(map[string]bool, len(draft.ReferencedFacts))
	for _, factID := range draft.ReferencedFacts {
		if !allowed[factID] {
			return fmt.Errorf("dialogue references unavailable fact %q", factID)
		}
		if seen[factID] {
			return fmt.Errorf("dialogue references fact %q more than once", factID)
		}
		seen[factID] = true
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
	return nil
}

package ai

import (
	"fmt"
	"strings"
	"unicode/utf8"

	"narra/internal/app"
)

var validEmotions = map[string]bool{"neutral": true, "alert": true, "troubled": true, "decisive": true}
var validDialogueActs = map[string]bool{"greet": true, "invite": true, "question": true, "warn": true, "refuse": true, "acknowledge": true}

func validateDialogue(snapshot app.DialogueSnapshot, draft *DialogueDraft) error {
	draft.Utterance = strings.TrimSpace(draft.Utterance)
	maxCharacters := snapshot.Scenario.HardMaxCharacters
	if maxCharacters <= 0 {
		return fmt.Errorf("dialogue language policy has no positive hard character limit")
	}
	length := utf8.RuneCountInString(draft.Utterance)
	if draft.Utterance == "" || length < snapshot.Scenario.MinCharacters || length > maxCharacters {
		return fmt.Errorf("dialogue utterance must contain %d to %d characters", snapshot.Scenario.MinCharacters, maxCharacters)
	}
	if countSentences(draft.Utterance) > snapshot.Scenario.MaxSentences {
		return fmt.Errorf("dialogue utterance exceeds the configured %d sentence limit", snapshot.Scenario.MaxSentences)
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
		if claim.Confidence == snapshot.Scenario.RumoredConfidence && !containsAny(draft.Utterance, snapshot.Scenario.UncertaintyMarkers) {
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
	for _, forbidden := range snapshot.Scenario.ForbiddenTerms {
		if strings.Contains(draft.Utterance, forbidden) {
			return fmt.Errorf("dialogue uses scenario-forbidden term %q", forbidden)
		}
	}
	return nil
}

func countSentences(value string) int {
	count, previousTerminator := 0, false
	for _, character := range value {
		terminator := strings.ContainsRune("。！？.!?", character)
		if terminator && !previousTerminator {
			count++
		}
		previousTerminator = terminator
	}
	if count == 0 && strings.TrimSpace(value) != "" {
		return 1
	}
	return count
}

func containsAny(value string, candidates []string) bool {
	for _, candidate := range candidates {
		if strings.Contains(value, candidate) {
			return true
		}
	}
	return false
}

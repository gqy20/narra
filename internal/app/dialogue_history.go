package app

import (
	"fmt"
	"strings"
	"unicode/utf8"
)

// DialogueExchange is non-authoritative presentation history. It is persisted
// for conversational continuity but never replayed as a world action.
type DialogueExchange struct {
	ActorID          string   `json:"actor_id"`
	Revision         string   `json:"revision"`
	PlayerText       string   `json:"player_text,omitempty"`
	NPCText          string   `json:"npc_text"`
	Emotion          string   `json:"emotion"`
	DialogueAct      string   `json:"dialogue_act"`
	ReferencedFacts  []string `json:"referenced_fact_ids,omitempty"`
	SuggestedActions []string `json:"suggested_action_ids,omitempty"`
}

func (s *Session) RecordDialogue(exchange DialogueExchange) error {
	exchange.PlayerText = strings.TrimSpace(exchange.PlayerText)
	exchange.NPCText = strings.TrimSpace(exchange.NPCText)
	if exchange.ActorID == "" || exchange.Revision == "" || exchange.NPCText == "" {
		return fmt.Errorf("dialogue exchange requires actor, revision, and NPC text")
	}
	if utf8.RuneCountInString(exchange.PlayerText) > 500 {
		return fmt.Errorf("player dialogue must not exceed 500 characters")
	}
	if exchange.Revision != s.DialogueRevision(exchange.ActorID) {
		return fmt.Errorf("dialogue revision is stale")
	}
	if _, err := s.DialogueSnapshotFor(exchange.ActorID, "focus"); err != nil {
		return err
	}
	exchange.ReferencedFacts = append([]string(nil), exchange.ReferencedFacts...)
	exchange.SuggestedActions = append([]string(nil), exchange.SuggestedActions...)
	s.dialogues = append(s.dialogues, exchange)
	return nil
}

func (s *Session) DialogueHistory(actorID, revision string, limit int) []DialogueExchange {
	if limit <= 0 {
		return nil
	}
	result := make([]DialogueExchange, 0, limit)
	for index := len(s.dialogues) - 1; index >= 0 && len(result) < limit; index-- {
		exchange := s.dialogues[index]
		if exchange.ActorID != actorID || exchange.Revision != revision {
			continue
		}
		exchange.ReferencedFacts = append([]string(nil), exchange.ReferencedFacts...)
		exchange.SuggestedActions = append([]string(nil), exchange.SuggestedActions...)
		result = append(result, exchange)
	}
	for left, right := 0, len(result)-1; left < right; left, right = left+1, right-1 {
		result[left], result[right] = result[right], result[left]
	}
	return result
}

func (s *Session) dialogueHistory() []DialogueExchange {
	result := make([]DialogueExchange, len(s.dialogues))
	copy(result, s.dialogues)
	for index := range result {
		result[index].ReferencedFacts = append([]string(nil), result[index].ReferencedFacts...)
		result[index].SuggestedActions = append([]string(nil), result[index].SuggestedActions...)
	}
	return result
}

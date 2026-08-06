// Package ai generates optional, non-authoritative narrative presentation.
// It must never settle game rules or mutate the simulation state.
package ai

import "context"

type Dialogue struct {
	ActorID            string   `json:"actor_id"`
	Revision           string   `json:"state_revision"`
	Utterance          string   `json:"utterance"`
	Emotion            string   `json:"emotion"`
	DialogueAct        string   `json:"dialogue_act"`
	ReferencedFacts    []string `json:"referenced_fact_ids"`
	RecognizedActionID string   `json:"-"`
	Source             string   `json:"source"`
}

type DialogueDraft struct {
	Utterance             string   `json:"utterance"`
	Emotion               string   `json:"emotion"`
	DialogueAct           string   `json:"dialogue_act"`
	ReferencedFacts       []string `json:"referenced_fact_ids"`
	RecognizedActionIndex int      `json:"recognized_action_index"`
}

type GenerationRequest struct {
	System           string
	Input            string
	AllowedFactIDs   []string
	AllowedActionIDs []string
}

type GenerationMetadata struct {
	Model        string
	RequestID    string
	InputTokens  int64
	OutputTokens int64
}

type Provider interface {
	GenerateDialogue(context.Context, GenerationRequest) (DialogueDraft, GenerationMetadata, error)
}

type WorldDirectiveDraft struct {
	DirectiveID        string `json:"directive_id"`
	Reason             string `json:"reason"`
	FocusSignalIndexes []int  `json:"focus_signal_indexes"`
}

type WorldDirectiveRequest struct {
	System              string
	Input               string
	AllowedDirectiveIDs []string
}

type WorldDirectiveProvider interface {
	GenerateWorldDirective(context.Context, WorldDirectiveRequest) (WorldDirectiveDraft, GenerationMetadata, error)
}

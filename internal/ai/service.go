package ai

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"
	"unicode/utf8"

	"fantu/internal/app"
	"fantu/internal/director"
)

type Service struct {
	provider Provider
	timeout  time.Duration
	cache    *dialogueCache
}

type ServiceOptions struct {
	Timeout   time.Duration
	CacheSize int
}

var ErrUnavailable = errors.New("AI dialogue is not enabled")
var ErrWorldDirectorUnavailable = errors.New("AI world director is not enabled")

func NewService(provider Provider, options ServiceOptions) *Service {
	if options.Timeout <= 0 {
		options.Timeout = 60 * time.Second
	}
	if options.CacheSize <= 0 {
		options.CacheSize = 128
	}
	return &Service{provider: provider, timeout: options.Timeout, cache: newDialogueCache(options.CacheSize)}
}

func (s *Service) Enabled() bool { return s != nil && s.provider != nil }

// SelectWorldDirective asks the model to choose exactly one engine-provided
// candidate. It cannot author effects, and any missing or invalid output is an
// error so Engine.Step can roll back the complete day.
func (s *Service) SelectWorldDirective(ctx context.Context, request director.SelectionRequest) (director.Selection, error) {
	if s == nil || s.provider == nil {
		return director.Selection{}, ErrWorldDirectorUnavailable
	}
	provider, ok := s.provider.(WorldDirectiveProvider)
	if !ok {
		return director.Selection{}, ErrWorldDirectorUnavailable
	}
	if len(request.Candidates) == 0 {
		return director.Selection{}, fmt.Errorf("world director request has no candidates")
	}
	allowed := make([]string, 0, len(request.Candidates))
	for _, candidate := range request.Candidates {
		allowed = append(allowed, candidate.DirectiveID)
	}
	input, err := json.Marshal(request)
	if err != nil {
		return director.Selection{}, fmt.Errorf("encode world director snapshot: %w", err)
	}
	callCtx, cancel := context.WithTimeout(ctx, s.timeout)
	defer cancel()
	draft, _, err := provider.GenerateWorldDirective(callCtx, WorldDirectiveRequest{
		System: "You are a bounded game world director. Choose exactly one directive_id from candidates. Never invent effects or IDs. Explain the pacing reason briefly and list only signal descriptions present in the snapshot.",
		Input:  string(input), AllowedDirectiveIDs: allowed,
	})
	if err != nil {
		return director.Selection{}, fmt.Errorf("generate world directive: %w", err)
	}
	draft.DirectiveID = strings.TrimSpace(draft.DirectiveID)
	draft.Reason = strings.TrimSpace(draft.Reason)
	if draft.DirectiveID == "" || draft.Reason == "" {
		return director.Selection{}, fmt.Errorf("world director response requires directive_id and reason")
	}
	valid := false
	for _, id := range allowed {
		if id == draft.DirectiveID {
			valid = true
			break
		}
	}
	if !valid {
		return director.Selection{}, fmt.Errorf("world director returned unavailable directive_id %q", draft.DirectiveID)
	}
	if len(draft.FocusSignals) > 5 {
		return director.Selection{}, fmt.Errorf("world director returned too many focus signals")
	}
	allowedSignals := make(map[string]bool)
	for _, candidate := range request.Candidates {
		if candidate.DirectiveID != draft.DirectiveID {
			continue
		}
		for _, signal := range candidate.Signals {
			allowedSignals[signal.Description] = true
		}
	}
	for _, signal := range draft.FocusSignals {
		if !allowedSignals[signal] {
			return director.Selection{}, fmt.Errorf("world director returned unknown focus signal %q", signal)
		}
	}
	return director.Selection{DirectiveID: draft.DirectiveID, Reason: draft.Reason, FocusSignals: append([]string(nil), draft.FocusSignals...), Source: "anthropic"}, nil
}

// GenerateConversationTurn returns one validated NPC reply using only the
// redacted snapshot and bounded, non-authoritative conversation history.
func (s *Service) GenerateConversationTurn(ctx context.Context, snapshot app.DialogueSnapshot, history []app.DialogueExchange, playerText string) (Dialogue, error) {
	if s == nil || s.provider == nil {
		return Dialogue{}, ErrUnavailable
	}
	playerText = strings.TrimSpace(playerText)
	if utf8.RuneCountInString(playerText) > 500 {
		return Dialogue{}, fmt.Errorf("player dialogue must not exceed 500 characters")
	}
	if len(history) > 8 {
		history = history[len(history)-8:]
	}
	if err := validateConversationHistory(snapshot, history); err != nil {
		return Dialogue{}, fmt.Errorf("validate dialogue history: %w", err)
	}
	payload := struct {
		Snapshot      app.DialogueSnapshot   `json:"snapshot"`
		History       []app.DialogueExchange `json:"history,omitempty"`
		PlayerMessage string                 `json:"player_message,omitempty"`
		Opening       bool                   `json:"opening"`
		Resume        bool                   `json:"resume"`
	}{
		Snapshot: snapshot, History: history, PlayerMessage: playerText,
		Opening: playerText == "" && len(history) == 0,
		Resume:  playerText == "" && len(history) > 0,
	}
	input, err := json.Marshal(payload)
	if err != nil {
		return Dialogue{}, fmt.Errorf("encode dialogue snapshot: %w", err)
	}
	key := fmt.Sprintf("%s:%x", promptVersion, sha256.Sum256(input))
	if cached, ok := s.cache.get(key); ok {
		cached.Source = "cache"
		return cached, nil
	}
	callCtx, cancel := context.WithTimeout(ctx, s.timeout)
	defer cancel()
	allowedFactIDs := make([]string, 0, len(snapshot.AllowedClaims))
	for _, claim := range snapshot.AllowedClaims {
		allowedFactIDs = append(allowedFactIDs, claim.FactID)
	}
	allowedActionIDs := make([]string, 0, len(snapshot.AvailableActions))
	for _, action := range snapshot.AvailableActions {
		allowedActionIDs = append(allowedActionIDs, action.ID)
	}
	draft, _, err := s.provider.GenerateDialogue(callCtx, GenerationRequest{
		System:           npcConversationSystemPrompt,
		Input:            fmt.Sprintf("This is the dialogue context redacted by the authoritative game rules. Generate the NPC's next response:\n%s", input),
		AllowedFactIDs:   allowedFactIDs,
		AllowedActionIDs: allowedActionIDs,
	})
	if err != nil {
		return Dialogue{}, fmt.Errorf("generate dialogue: %w", err)
	}
	if err := validateDialogue(snapshot, &draft); err != nil {
		return Dialogue{}, fmt.Errorf("validate dialogue: %w", err)
	}
	result := Dialogue{
		ActorID: snapshot.Actor.ID, Revision: snapshot.Revision,
		Utterance: draft.Utterance, Emotion: draft.Emotion, DialogueAct: draft.DialogueAct,
		ReferencedFacts:  append([]string{}, draft.ReferencedFacts...),
		SuggestedActions: append([]string{}, draft.SuggestedActions...), Source: "anthropic",
	}
	s.cache.put(key, result)
	return result, nil
}

func validateConversationHistory(snapshot app.DialogueSnapshot, history []app.DialogueExchange) error {
	for index, exchange := range history {
		if exchange.ActorID != snapshot.Actor.ID || exchange.Revision != snapshot.Revision {
			return fmt.Errorf("exchange %d does not match current actor and revision", index+1)
		}
		if utf8.RuneCountInString(exchange.PlayerText) > 500 {
			return fmt.Errorf("exchange %d player text is too long", index+1)
		}
		draft := DialogueDraft{
			Utterance: exchange.NPCText, Emotion: exchange.Emotion, DialogueAct: exchange.DialogueAct,
			ReferencedFacts: exchange.ReferencedFacts, SuggestedActions: exchange.SuggestedActions,
		}
		if err := validateDialogue(snapshot, &draft); err != nil {
			return fmt.Errorf("exchange %d: %w", index+1, err)
		}
	}
	return nil
}

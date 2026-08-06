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

	"narra/internal/app"
	"narra/internal/director"
	"narra/internal/domain"
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

// TestConnectivity performs one non-authoritative structured request without
// changing runtime configuration or game state.
func (s *Service) TestConnectivity(ctx context.Context) error {
	if s == nil || s.provider == nil {
		return ErrUnavailable
	}
	callCtx, cancel := context.WithTimeout(ctx, s.timeout)
	defer cancel()
	draft, _, err := s.provider.GenerateDialogue(callCtx, GenerationRequest{
		System: "This is a connectivity test. Return one short acknowledgement using the required JSON schema. Do not reference facts or actions. Set recognized_action_index to -1.",
		Input:  `{"purpose":"connectivity_test","locale":"zh-CN"}`,
	})
	if err != nil {
		return fmt.Errorf("connectivity request: %w", err)
	}
	if strings.TrimSpace(draft.Utterance) == "" {
		return errors.New("connectivity response contains an empty utterance")
	}
	if draft.Emotion == "" || draft.DialogueAct == "" {
		return errors.New("connectivity response is missing required structured fields")
	}
	if draft.RecognizedActionIndex != -1 {
		return errors.New("connectivity response recognized an unavailable action")
	}
	_, err = s.SelectWorldDirective(callCtx, director.SelectionRequest{
		ScenarioID: "connectivity-test", Day: 1, Phase: "probe",
		Candidates: []director.Candidate{{
			DirectiveID: "connectivity-probe", Description: "Connectivity probe",
			Signals: []domain.WorldSignal{{Type: "probe", SubjectID: "service", Value: 1, Description: "连接测试信号"}},
		}},
	})
	if err != nil {
		return fmt.Errorf("world director connectivity request: %w", err)
	}
	return nil
}

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
		System: "You are a bounded game world director. Choose exactly one directive_id from candidates. Never invent effects or IDs. Explain the pacing reason briefly. Return focus_signal_indexes as zero-based indexes into the selected candidate's signals array; never repeat or rewrite signal descriptions.",
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
	if len(draft.FocusSignalIndexes) > 5 {
		return director.Selection{}, fmt.Errorf("world director returned too many focus signals")
	}
	var selectedSignals []domain.WorldSignal
	for _, candidate := range request.Candidates {
		if candidate.DirectiveID != draft.DirectiveID {
			continue
		}
		selectedSignals = candidate.Signals
		break
	}
	focusSignals := make([]string, 0, len(draft.FocusSignalIndexes))
	seenSignalIndexes := make(map[int]bool)
	for _, index := range draft.FocusSignalIndexes {
		if index < 0 || index >= len(selectedSignals) {
			return director.Selection{}, fmt.Errorf("world director returned unavailable focus signal index %d", index)
		}
		if seenSignalIndexes[index] {
			continue
		}
		seenSignalIndexes[index] = true
		focusSignals = append(focusSignals, selectedSignals[index].Description)
	}
	return director.Selection{DirectiveID: draft.DirectiveID, Reason: draft.Reason, FocusSignals: focusSignals, Source: "anthropic"}, nil
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
		ReferencedFacts: append([]string{}, draft.ReferencedFacts...), Source: "anthropic",
	}
	if draft.RecognizedActionIndex >= 0 {
		result.RecognizedActionID = snapshot.AvailableActions[draft.RecognizedActionIndex].ID
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
			ReferencedFacts: exchange.ReferencedFacts, RecognizedActionIndex: -1,
		}
		if err := validateDialogue(snapshot, &draft); err != nil {
			return fmt.Errorf("exchange %d: %w", index+1, err)
		}
	}
	return nil
}

package ai

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"fantu/internal/app"
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

func NewService(provider Provider, options ServiceOptions) *Service {
	if options.Timeout <= 0 {
		options.Timeout = 12 * time.Second
	}
	if options.CacheSize <= 0 {
		options.CacheSize = 128
	}
	return &Service{provider: provider, timeout: options.Timeout, cache: newDialogueCache(options.CacheSize)}
}

func (s *Service) Enabled() bool { return s != nil && s.provider != nil }

// GenerateDialogue returns a validated model response or an explicit error.
// It never fabricates a local replacement for a failed model call.
func (s *Service) GenerateDialogueDetailed(ctx context.Context, snapshot app.DialogueSnapshot) (Dialogue, error) {
	if s == nil || s.provider == nil {
		return Dialogue{}, ErrUnavailable
	}
	input, err := json.Marshal(snapshot)
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
	draft, _, err := s.provider.GenerateDialogue(callCtx, GenerationRequest{
		System:         npcFocusSystemPrompt,
		Input:          fmt.Sprintf("以下是经过游戏规则裁剪的本次人物上下文。只根据这些内容生成一句当前开场话：\n%s", input),
		AllowedFactIDs: allowedFactIDs,
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
		ReferencedFacts: append([]string(nil), draft.ReferencedFacts...), Source: "anthropic",
	}
	s.cache.put(key, result)
	return result, nil
}

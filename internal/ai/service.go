package ai

import (
	"context"
	"crypto/sha256"
	"encoding/json"
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

// GenerateDialogue always returns displayable dialogue. Provider, validation,
// and timeout failures use a local fallback and never become gameplay errors.
func (s *Service) GenerateDialogue(ctx context.Context, snapshot app.DialogueSnapshot) Dialogue {
	input, err := json.Marshal(snapshot)
	if err != nil {
		return fallbackDialogue(snapshot)
	}
	key := fmt.Sprintf("%s:%x", promptVersion, sha256.Sum256(input))
	if cached, ok := s.cache.get(key); ok {
		cached.Source = "cache"
		return cached
	}
	if s.provider == nil {
		return fallbackDialogue(snapshot)
	}
	callCtx, cancel := context.WithTimeout(ctx, s.timeout)
	defer cancel()
	draft, _, err := s.provider.GenerateDialogue(callCtx, GenerationRequest{
		System: npcFocusSystemPrompt,
		Input:  fmt.Sprintf("以下是经过游戏规则裁剪的本次人物上下文。只根据这些内容生成一句当前开场话：\n%s", input),
	})
	if err != nil || validateDialogue(snapshot, &draft) != nil {
		return fallbackDialogue(snapshot)
	}
	result := Dialogue{
		ActorID: snapshot.Actor.ID, Revision: snapshot.Revision,
		Utterance: draft.Utterance, Emotion: draft.Emotion, DialogueAct: draft.DialogueAct,
		ReferencedFacts: append([]string(nil), draft.ReferencedFacts...), Source: "anthropic",
	}
	s.cache.put(key, result)
	return result
}

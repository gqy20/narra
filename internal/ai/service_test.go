package ai

import (
	"context"
	"testing"
	"time"

	"fantu/internal/app"
)

type fakeProvider struct {
	draft aiTestDraft
	calls int
	wait  bool
}

type aiTestDraft struct {
	value DialogueDraft
	err   error
}

func (p *fakeProvider) GenerateDialogue(ctx context.Context, _ GenerationRequest) (DialogueDraft, GenerationMetadata, error) {
	p.calls++
	if p.wait {
		<-ctx.Done()
		return DialogueDraft{}, GenerationMetadata{}, ctx.Err()
	}
	return p.draft.value, GenerationMetadata{Model: "fake"}, p.draft.err
}

func dialogueTestSnapshot() app.DialogueSnapshot {
	return app.DialogueSnapshot{
		Revision: "blackwind:0:0:N01", ScenarioID: "blackwind", Situation: "focus",
		Actor:         app.DialogueActor{ID: "N01", Name: "李玄", SpeechGuidance: []string{"保持克制"}},
		Player:        app.DialoguePlayer{ID: "P00", Name: "测试玩家"},
		AllowedClaims: []app.DialogueClaim{{FactID: "F02", Claim: "一条传闻", Confidence: "只是听说"}},
	}
}

func TestServiceValidatesAndCachesProviderDialogue(t *testing.T) {
	provider := &fakeProvider{draft: aiTestDraft{value: DialogueDraft{
		Utterance: "这条消息，你是从哪里听来的？", Emotion: "alert", DialogueAct: "question",
		ReferencedFacts: []string{"F02"},
	}}}
	service := NewService(provider, ServiceOptions{Timeout: time.Second, CacheSize: 4})
	first := service.GenerateDialogue(context.Background(), dialogueTestSnapshot())
	second := service.GenerateDialogue(context.Background(), dialogueTestSnapshot())
	if first.Source != "anthropic" || second.Source != "cache" || provider.calls != 1 {
		t.Fatalf("dialogue/cache = %+v / %+v, calls=%d", first, second, provider.calls)
	}
}

func TestServiceCacheSeparatesSnapshotsWithSameRevision(t *testing.T) {
	provider := &fakeProvider{draft: aiTestDraft{value: DialogueDraft{
		Utterance: "请讲。", Emotion: "neutral", DialogueAct: "invite", ReferencedFacts: []string{},
	}}}
	service := NewService(provider, ServiceOptions{Timeout: time.Second, CacheSize: 4})
	first := dialogueTestSnapshot()
	second := dialogueTestSnapshot()
	second.Player.Name = "另一位玩家"
	service.GenerateDialogue(context.Background(), first)
	service.GenerateDialogue(context.Background(), second)
	if provider.calls != 2 {
		t.Fatalf("different snapshots shared one cache entry, calls=%d", provider.calls)
	}
}

func TestServiceFallsBackOnUnauthorizedFact(t *testing.T) {
	provider := &fakeProvider{draft: aiTestDraft{value: DialogueDraft{
		Utterance: "我知道那个秘密。", Emotion: "alert", DialogueAct: "warn",
		ReferencedFacts: []string{"F99"},
	}}}
	result := NewService(provider, ServiceOptions{}).GenerateDialogue(context.Background(), dialogueTestSnapshot())
	if result.Source != "fallback" || len(result.ReferencedFacts) != 0 {
		t.Fatalf("unauthorized dialogue was not rejected: %+v", result)
	}
}

func TestServiceFallsBackOnTimeout(t *testing.T) {
	provider := &fakeProvider{wait: true}
	service := NewService(provider, ServiceOptions{Timeout: time.Millisecond, CacheSize: 2})
	result := service.GenerateDialogue(context.Background(), dialogueTestSnapshot())
	if result.Source != "fallback" || provider.calls != 1 {
		t.Fatalf("timeout dialogue = %+v, calls=%d", result, provider.calls)
	}
}

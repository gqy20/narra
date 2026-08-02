package ai

import (
	"context"
	"errors"
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
	first, firstErr := service.GenerateDialogueDetailed(context.Background(), dialogueTestSnapshot())
	second, secondErr := service.GenerateDialogueDetailed(context.Background(), dialogueTestSnapshot())
	if firstErr != nil || secondErr != nil || first.Source != "anthropic" || second.Source != "cache" || provider.calls != 1 {
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
	if _, err := service.GenerateDialogueDetailed(context.Background(), first); err != nil {
		t.Fatal(err)
	}
	if _, err := service.GenerateDialogueDetailed(context.Background(), second); err != nil {
		t.Fatal(err)
	}
	if provider.calls != 2 {
		t.Fatalf("different snapshots shared one cache entry, calls=%d", provider.calls)
	}
}

func TestServiceFallsBackOnUnauthorizedFact(t *testing.T) {
	provider := &fakeProvider{draft: aiTestDraft{value: DialogueDraft{
		Utterance: "我知道那个秘密。", Emotion: "alert", DialogueAct: "warn",
		ReferencedFacts: []string{"F99"},
	}}}
	result, err := NewService(provider, ServiceOptions{}).GenerateDialogueDetailed(context.Background(), dialogueTestSnapshot())
	if result.Source != "" || result.Utterance != "" || err == nil {
		t.Fatalf("unauthorized dialogue was not rejected: %+v, err=%v", result, err)
	}
}

func TestServiceFallsBackOnTimeout(t *testing.T) {
	provider := &fakeProvider{wait: true}
	service := NewService(provider, ServiceOptions{Timeout: time.Millisecond, CacheSize: 2})
	result, err := service.GenerateDialogueDetailed(context.Background(), dialogueTestSnapshot())
	if result.Source != "" || result.Utterance != "" || err == nil || provider.calls != 1 {
		t.Fatalf("timeout dialogue = %+v, calls=%d", result, provider.calls)
	}
}

func TestServiceReturnsUnavailableWithoutProvider(t *testing.T) {
	result, err := NewService(nil, ServiceOptions{}).GenerateDialogueDetailed(context.Background(), dialogueTestSnapshot())
	if result.Source != "" || result.Utterance != "" || !errors.Is(err, ErrUnavailable) {
		t.Fatalf("disabled dialogue = %+v, err=%v", result, err)
	}
}

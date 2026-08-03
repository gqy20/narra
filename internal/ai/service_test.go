package ai

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"fantu/internal/app"
)

type fakeProvider struct {
	draft       aiTestDraft
	calls       int
	wait        bool
	lastRequest GenerationRequest
}

type aiTestDraft struct {
	value DialogueDraft
	err   error
}

func (p *fakeProvider) GenerateDialogue(ctx context.Context, request GenerationRequest) (DialogueDraft, GenerationMetadata, error) {
	p.calls++
	p.lastRequest = request
	if p.wait {
		<-ctx.Done()
		return DialogueDraft{}, GenerationMetadata{}, ctx.Err()
	}
	return p.draft.value, GenerationMetadata{Model: "fake"}, p.draft.err
}

func dialogueTestSnapshot() app.DialogueSnapshot {
	return app.DialogueSnapshot{
		Revision: "blackwind:0:0:N01", ScenarioID: "blackwind", Situation: "focus",
		Scenario:         app.DialogueScenario{Title: "测试场景", Context: "架空城邦调查", PlayerAddress: "先生", Style: "克制的调查叙事口吻"},
		Actor:            app.DialogueActor{ID: "N01", Name: "李玄", SpeechGuidance: []string{"保持克制"}},
		Player:           app.DialoguePlayer{ID: "P00", Name: "测试玩家"},
		AllowedClaims:    []app.DialogueClaim{{FactID: "F02", Claim: "一条传闻", Confidence: "只是听说"}},
		AvailableActions: []app.DialogueAction{{ID: "tell:N01:F02", Name: "告知线索"}},
	}
}

func TestConversationPromptUsesScenarioDialogueContext(t *testing.T) {
	provider := &fakeProvider{draft: aiTestDraft{value: DialogueDraft{
		Utterance: "这份记录还需核对。", Emotion: "neutral", DialogueAct: "acknowledge",
	}}}
	_, err := NewService(provider, ServiceOptions{}).GenerateConversationTurn(context.Background(), dialogueTestSnapshot(), nil, "")
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(provider.lastRequest.System, "凡途") || strings.Contains(provider.lastRequest.System, "修仙") || strings.Contains(provider.lastRequest.System, "道友") {
		t.Fatalf("system prompt still contains scenario-specific language: %s", provider.lastRequest.System)
	}
	if !strings.Contains(provider.lastRequest.Input, "架空城邦调查") || !strings.Contains(provider.lastRequest.Input, "克制的调查叙事口吻") {
		t.Fatalf("scenario dialogue metadata was omitted: %s", provider.lastRequest.Input)
	}
}

func TestConversationTurnIncludesHistoryAndPlayerMessage(t *testing.T) {
	provider := &fakeProvider{draft: aiTestDraft{value: DialogueDraft{
		Utterance: "我会先核验来源。", Emotion: "decisive", DialogueAct: "acknowledge",
		ReferencedFacts: []string{}, SuggestedActions: []string{"tell:N01:F02"},
	}}}
	service := NewService(provider, ServiceOptions{Timeout: time.Second})
	history := []app.DialogueExchange{{ActorID: "N01", Revision: "blackwind:0:0:N01", NPCText: "先说来意。", Emotion: "neutral", DialogueAct: "invite"}}
	result, err := service.GenerateConversationTurn(context.Background(), dialogueTestSnapshot(), history, "你会如何核验？")
	if err != nil || len(result.SuggestedActions) != 1 {
		t.Fatalf("conversation result=%+v err=%v", result, err)
	}
	if !strings.Contains(provider.lastRequest.Input, "你会如何核验") || !strings.Contains(provider.lastRequest.Input, "先说来意") {
		t.Fatalf("conversation request omitted history/message: %s", provider.lastRequest.Input)
	}
	if len(provider.lastRequest.AllowedActionIDs) != 1 || provider.lastRequest.AllowedActionIDs[0] != "tell:N01:F02" {
		t.Fatalf("allowed actions = %#v", provider.lastRequest.AllowedActionIDs)
	}
}

func TestConversationRejectsUnavailableSuggestedAction(t *testing.T) {
	provider := &fakeProvider{draft: aiTestDraft{value: DialogueDraft{
		Utterance: "你可以把东西交给我。", Emotion: "neutral", DialogueAct: "invite",
		ReferencedFacts: []string{}, SuggestedActions: []string{"grant-secret-reward"},
	}}}
	result, err := NewService(provider, ServiceOptions{}).GenerateConversationTurn(context.Background(), dialogueTestSnapshot(), nil, "有什么办法？")
	if err == nil || result.Utterance != "" {
		t.Fatalf("unavailable suggestion was accepted: result=%+v err=%v", result, err)
	}
}

func TestConversationResumeIsDistinctFromFreshOpening(t *testing.T) {
	provider := &fakeProvider{draft: aiTestDraft{value: DialogueDraft{
		Utterance: "方才说到那条消息，我们接着谈。", Emotion: "neutral", DialogueAct: "acknowledge",
		ReferencedFacts: []string{}, SuggestedActions: []string{},
	}}}
	history := []app.DialogueExchange{{
		ActorID: "N01", Revision: "blackwind:0:0:N01", PlayerText: "先记下此事。",
		NPCText: "我记下了。", Emotion: "neutral", DialogueAct: "acknowledge",
	}}
	if _, err := NewService(provider, ServiceOptions{}).GenerateConversationTurn(context.Background(), dialogueTestSnapshot(), history, ""); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(provider.lastRequest.Input, `"resume":true`) || !strings.Contains(provider.lastRequest.Input, `"opening":false`) {
		t.Fatalf("resume request flags are wrong: %s", provider.lastRequest.Input)
	}
}

func TestDialogueRequiresUncertaintyForRumoredFacts(t *testing.T) {
	snapshot := dialogueTestSnapshot()
	definite := DialogueDraft{
		Utterance: "青髓芝会在那一日成熟。", Emotion: "neutral", DialogueAct: "acknowledge",
		ReferencedFacts: []string{"F02"}, SuggestedActions: []string{},
	}
	if err := validateDialogue(snapshot, &definite); err == nil {
		t.Fatal("rumored fact was stated as certain")
	}
	qualified := DialogueDraft{
		Utterance: "传闻说青髓芝会在那一日成熟，真假仍需核验。", Emotion: "neutral", DialogueAct: "acknowledge",
		ReferencedFacts: []string{"F02"}, SuggestedActions: []string{},
	}
	if err := validateDialogue(snapshot, &qualified); err != nil {
		t.Fatalf("qualified rumor was rejected: %v", err)
	}
}

func TestDialogueRejectsUnsupportedSelfAddress(t *testing.T) {
	draft := DialogueDraft{
		Utterance: "小老儿这里自有办法。", Emotion: "neutral", DialogueAct: "acknowledge",
		ReferencedFacts: []string{}, SuggestedActions: []string{},
	}
	if err := validateDialogue(dialogueTestSnapshot(), &draft); err == nil {
		t.Fatal("unsupported self-address was accepted")
	}
}

func TestServiceValidatesAndCachesProviderDialogue(t *testing.T) {
	provider := &fakeProvider{draft: aiTestDraft{value: DialogueDraft{
		Utterance: "听说的这条消息，你是从哪里得来的？", Emotion: "alert", DialogueAct: "question",
		ReferencedFacts: []string{"F02"},
	}}}
	service := NewService(provider, ServiceOptions{Timeout: time.Second, CacheSize: 4})
	first, firstErr := service.GenerateConversationTurn(context.Background(), dialogueTestSnapshot(), nil, "")
	second, secondErr := service.GenerateConversationTurn(context.Background(), dialogueTestSnapshot(), nil, "")
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
	if _, err := service.GenerateConversationTurn(context.Background(), first, nil, ""); err != nil {
		t.Fatal(err)
	}
	if _, err := service.GenerateConversationTurn(context.Background(), second, nil, ""); err != nil {
		t.Fatal(err)
	}
	if provider.calls != 2 {
		t.Fatalf("different snapshots shared one cache entry, calls=%d", provider.calls)
	}
}

func TestServiceRejectsUnauthorizedFact(t *testing.T) {
	provider := &fakeProvider{draft: aiTestDraft{value: DialogueDraft{
		Utterance: "我知道那个秘密。", Emotion: "alert", DialogueAct: "warn",
		ReferencedFacts: []string{"F99"},
	}}}
	result, err := NewService(provider, ServiceOptions{}).GenerateConversationTurn(context.Background(), dialogueTestSnapshot(), nil, "")
	if result.Source != "" || result.Utterance != "" || err == nil {
		t.Fatalf("unauthorized dialogue was not rejected: %+v, err=%v", result, err)
	}
}

func TestServiceReturnsErrorOnTimeout(t *testing.T) {
	provider := &fakeProvider{wait: true}
	service := NewService(provider, ServiceOptions{Timeout: time.Millisecond, CacheSize: 2})
	result, err := service.GenerateConversationTurn(context.Background(), dialogueTestSnapshot(), nil, "")
	if result.Source != "" || result.Utterance != "" || err == nil || provider.calls != 1 {
		t.Fatalf("timeout dialogue = %+v, calls=%d", result, provider.calls)
	}
}

func TestServiceReturnsUnavailableWithoutProvider(t *testing.T) {
	result, err := NewService(nil, ServiceOptions{}).GenerateConversationTurn(context.Background(), dialogueTestSnapshot(), nil, "")
	if result.Source != "" || result.Utterance != "" || !errors.Is(err, ErrUnavailable) {
		t.Fatalf("disabled dialogue = %+v, err=%v", result, err)
	}
}

// Package anthropic implements the narrative provider with Anthropic's
// official Go SDK.
package anthropic

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"fantu/internal/ai"

	anthropicsdk "github.com/anthropics/anthropic-sdk-go"
	"github.com/anthropics/anthropic-sdk-go/option"
)

type Config struct {
	APIKey     string
	Model      string
	BaseURL    string
	MaxTokens  int64
	MaxRetries int
}

type Client struct {
	sdk       anthropicsdk.Client
	model     string
	maxTokens int64
}

func New(config Config) (*Client, error) {
	if strings.TrimSpace(config.APIKey) == "" {
		return nil, fmt.Errorf("anthropic API key is empty")
	}
	if strings.TrimSpace(config.Model) == "" {
		return nil, fmt.Errorf("anthropic model is empty")
	}
	if config.MaxTokens <= 0 {
		config.MaxTokens = 1024
	}
	options := []option.RequestOption{
		option.WithAPIKey(config.APIKey),
		option.WithMaxRetries(config.MaxRetries),
	}
	if config.BaseURL != "" {
		options = append(options, option.WithBaseURL(normalizeBaseURL(config.BaseURL)))
	}
	return &Client{sdk: anthropicsdk.NewClient(options...), model: config.Model, maxTokens: config.MaxTokens}, nil
}

func normalizeBaseURL(value string) string {
	value = strings.TrimRight(strings.TrimSpace(value), "/")
	return strings.TrimSuffix(value, "/v1/messages")
}

func (c *Client) GenerateDialogue(ctx context.Context, request ai.GenerationRequest) (ai.DialogueDraft, ai.GenerationMetadata, error) {
	message, err := c.sdk.Messages.New(ctx, anthropicsdk.MessageNewParams{
		Model:     anthropicsdk.Model(c.model),
		MaxTokens: c.maxTokens,
		System:    []anthropicsdk.TextBlockParam{{Text: request.System}},
		Messages: []anthropicsdk.MessageParam{
			anthropicsdk.NewUserMessage(anthropicsdk.NewTextBlock(request.Input)),
		},
		OutputConfig: anthropicsdk.OutputConfigParam{
			Effort: anthropicsdk.OutputConfigEffortLow,
			Format: anthropicsdk.JSONOutputFormatParam{Schema: dialogueSchemaFor(request.AllowedFactIDs, request.AllowedActionIDs)},
		},
	})
	if err != nil {
		return ai.DialogueDraft{}, ai.GenerationMetadata{}, fmt.Errorf("anthropic dialogue request: %w", err)
	}
	metadata := ai.GenerationMetadata{
		Model: c.model, RequestID: message.ID,
		InputTokens: message.Usage.InputTokens, OutputTokens: message.Usage.OutputTokens,
	}
	var output string
	for _, block := range message.Content {
		if block.Type == "text" {
			output = block.Text
			break
		}
	}
	if output == "" {
		return ai.DialogueDraft{}, metadata, fmt.Errorf("anthropic dialogue response contains no text block")
	}
	var draft ai.DialogueDraft
	if err := json.Unmarshal([]byte(output), &draft); err != nil {
		return ai.DialogueDraft{}, metadata, fmt.Errorf("decode anthropic dialogue: %w", err)
	}
	return draft, metadata, nil
}

func (c *Client) GenerateWorldDirective(ctx context.Context, request ai.WorldDirectiveRequest) (ai.WorldDirectiveDraft, ai.GenerationMetadata, error) {
	if len(request.AllowedDirectiveIDs) == 0 {
		return ai.WorldDirectiveDraft{}, ai.GenerationMetadata{}, fmt.Errorf("world directive request has no allowed IDs")
	}
	message, err := c.sdk.Messages.New(ctx, anthropicsdk.MessageNewParams{
		Model: anthropicsdk.Model(c.model), MaxTokens: c.maxTokens,
		System:       []anthropicsdk.TextBlockParam{{Text: request.System}},
		Messages:     []anthropicsdk.MessageParam{anthropicsdk.NewUserMessage(anthropicsdk.NewTextBlock(request.Input))},
		OutputConfig: anthropicsdk.OutputConfigParam{Effort: anthropicsdk.OutputConfigEffortLow, Format: anthropicsdk.JSONOutputFormatParam{Schema: worldDirectiveSchemaFor(request.AllowedDirectiveIDs)}},
	})
	if err != nil {
		return ai.WorldDirectiveDraft{}, ai.GenerationMetadata{}, fmt.Errorf("anthropic world director request: %w", err)
	}
	metadata := ai.GenerationMetadata{Model: c.model, RequestID: message.ID, InputTokens: message.Usage.InputTokens, OutputTokens: message.Usage.OutputTokens}
	var output string
	for _, block := range message.Content {
		if block.Type == "text" {
			output = block.Text
			break
		}
	}
	if strings.TrimSpace(output) == "" {
		return ai.WorldDirectiveDraft{}, metadata, fmt.Errorf("anthropic world director response contains no text block")
	}
	var draft ai.WorldDirectiveDraft
	if err := json.Unmarshal([]byte(output), &draft); err != nil {
		return ai.WorldDirectiveDraft{}, metadata, fmt.Errorf("decode anthropic world director: %w", err)
	}
	return draft, metadata, nil
}

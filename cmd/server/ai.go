package main

import (
	"flag"
	"fmt"
	"os"
	"time"

	"fantu/internal/ai"
	anthropicai "fantu/internal/ai/anthropic"
)

type aiFlags struct {
	enabled    *bool
	model      *string
	baseURL    *string
	maxTokens  *int
	timeout    *time.Duration
	maxRetries *int
}

func registerAIFlags() aiFlags {
	return aiFlags{
		enabled:    flag.Bool("ai-enabled", true, "enable optional Anthropic NPC dialogue when credentials are available"),
		model:      flag.String("ai-model", environmentOrDefault("ANTHROPIC_MODEL", "claude-haiku-4-5"), "Anthropic-compatible model used for NPC dialogue"),
		baseURL:    flag.String("ai-base-url", os.Getenv("ANTHROPIC_BASE_URL"), "optional Anthropic-compatible API base URL"),
		maxTokens:  flag.Int("ai-max-tokens", 1024, "maximum output tokens for NPC dialogue, including model reasoning"),
		timeout:    flag.Duration("ai-timeout", 12*time.Second, "maximum duration of an NPC dialogue generation"),
		maxRetries: flag.Int("ai-max-retries", 1, "maximum Anthropic SDK retries per dialogue request"),
	}
}

func buildDialogueService(config aiFlags) (*ai.Service, string, error) {
	options := ai.ServiceOptions{Timeout: *config.timeout, CacheSize: 128}
	if !*config.enabled {
		return ai.NewService(nil, options), "disabled", nil
	}
	apiKey := os.Getenv("ANTHROPIC_API_KEY")
	if apiKey == "" {
		return ai.NewService(nil, options), "fallback:no_api_key", nil
	}
	provider, err := anthropicai.New(anthropicai.Config{
		APIKey: apiKey, Model: *config.model, BaseURL: *config.baseURL,
		MaxTokens: int64(*config.maxTokens), MaxRetries: *config.maxRetries,
	})
	if err != nil {
		return nil, "", fmt.Errorf("configure Anthropic dialogue: %w", err)
	}
	return ai.NewService(provider, options), "anthropic:" + *config.model, nil
}

package main

import (
	"flag"
	"os"
	"time"

	"fantu/internal/ai"
	"fantu/internal/aiconfig"
)

type playAIFlags struct {
	enabled    *bool
	model      *string
	baseURL    *string
	maxTokens  *int
	timeout    *time.Duration
	maxRetries *int
}

func registerPlayAIFlags() playAIFlags {
	return playAIFlags{
		enabled:    flag.Bool("ai-enabled", true, "enable optional AI NPC dialogue when credentials are available"),
		model:      flag.String("ai-model", aiconfig.EnvironmentOrDefault("ANTHROPIC_MODEL", "claude-haiku-4-5"), "Anthropic-compatible model used for NPC dialogue"),
		baseURL:    flag.String("ai-base-url", os.Getenv("ANTHROPIC_BASE_URL"), "optional Anthropic-compatible API base URL"),
		maxTokens:  flag.Int("ai-max-tokens", 4096, "maximum output tokens for NPC dialogue, including model reasoning"),
		timeout:    flag.Duration("ai-timeout", 30*time.Second, "maximum duration of an NPC dialogue generation"),
		maxRetries: flag.Int("ai-max-retries", 1, "maximum SDK retries per dialogue request"),
	}
}

func buildPlayDialogueService(config playAIFlags) (*ai.Service, string, error) {
	return aiconfig.Build(aiconfig.Config{
		Enabled: *config.enabled, Model: *config.model, BaseURL: *config.baseURL,
		MaxTokens: int64(*config.maxTokens), Timeout: *config.timeout,
		MaxRetries: *config.maxRetries, CacheSize: 128,
	})
}

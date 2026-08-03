package main

import (
	"flag"
	"os"
	"strings"
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
	defaultEnabled := strings.TrimSpace(os.Getenv("ANTHROPIC_API_KEY")) != ""
	return playAIFlags{
		enabled:    flag.Bool("ai-enabled", defaultEnabled, "enable Anthropic NPC dialogue and world director; enabled calls must return valid structured output"),
		model:      flag.String("ai-model", aiconfig.EnvironmentOrDefault("ANTHROPIC_MODEL", "claude-haiku-4-5"), "Anthropic-compatible model used for NPC dialogue"),
		baseURL:    flag.String("ai-base-url", os.Getenv("ANTHROPIC_BASE_URL"), "optional Anthropic-compatible API base URL"),
		maxTokens:  flag.Int("ai-max-tokens", 4096, "maximum output tokens for NPC dialogue, including model reasoning"),
		timeout:    flag.Duration("ai-timeout", 60*time.Second, "maximum duration of an NPC dialogue generation"),
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

package main

import (
	"errors"
	"flag"
	"os"
	"strings"
	"time"

	"fantu/internal/ai"
	"fantu/internal/aiconfig"
	gameserver "fantu/internal/server"
)

type aiFlags struct {
	enabled    *bool
	model      *string
	baseURL    *string
	maxTokens  *int
	timeout    *time.Duration
	maxRetries *int
	settings   *string
}

func registerAIFlags() aiFlags {
	return aiFlags{
		enabled:    flag.Bool("ai-enabled", true, "enable optional Anthropic NPC dialogue when credentials are available"),
		model:      flag.String("ai-model", aiconfig.EnvironmentOrDefault("ANTHROPIC_MODEL", "claude-haiku-4-5"), "Anthropic-compatible model used for NPC dialogue"),
		baseURL:    flag.String("ai-base-url", os.Getenv("ANTHROPIC_BASE_URL"), "optional Anthropic-compatible API base URL"),
		maxTokens:  flag.Int("ai-max-tokens", 4096, "maximum output tokens for NPC dialogue, including model reasoning"),
		timeout:    flag.Duration("ai-timeout", 60*time.Second, "maximum duration of an NPC dialogue generation"),
		maxRetries: flag.Int("ai-max-retries", 1, "maximum Anthropic SDK retries per dialogue request"),
		settings:   flag.String("ai-settings", "", "JSON AI settings file; keeps credentials out of process arguments"),
	}
}

func buildDialogueService(config aiFlags) (*ai.Service, string, error) {
	resolved, err := aiconfig.LoadFile(*config.settings, aiconfig.Config{
		Enabled: *config.enabled, Model: *config.model, BaseURL: *config.baseURL,
		MaxTokens: int64(*config.maxTokens), Timeout: *config.timeout,
		MaxRetries: *config.maxRetries, CacheSize: 128,
	})
	if err != nil {
		return nil, "", err
	}
	return aiconfig.Build(resolved)
}

func buildRuntimeDialogueService(config aiFlags, settings gameserver.AISettings) (*ai.Service, string, error) {
	if settings.Enabled && strings.TrimSpace(settings.APIKey) == "" {
		return nil, "", errors.New("启用大模型时 API Key 不能为空")
	}
	return aiconfig.Build(aiconfig.Config{
		Enabled: settings.Enabled, APIKey: settings.APIKey,
		Model: strings.TrimSpace(settings.Model), BaseURL: strings.TrimSpace(settings.BaseURL),
		MaxTokens: int64(*config.maxTokens), Timeout: *config.timeout,
		MaxRetries: *config.maxRetries, CacheSize: 128,
	})
}

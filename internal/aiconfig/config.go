package aiconfig

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"
	"time"

	"narra/internal/ai"
	anthropicai "narra/internal/ai/anthropic"
)

type Config struct {
	Enabled    bool
	APIKey     string
	Model      string
	BaseURL    string
	MaxTokens  int64
	Timeout    time.Duration
	MaxRetries int
	CacheSize  int
}

type FileConfig struct {
	Enabled bool   `json:"enabled"`
	APIKey  string `json:"api_key"`
	Model   string `json:"model"`
	BaseURL string `json:"base_url"`
}

// LoadFile overlays user-facing AI settings on the supplied runtime defaults.
// The API key stays in this file and is never passed through process arguments.
func LoadFile(path string, defaults Config) (Config, error) {
	if strings.TrimSpace(path) == "" {
		return defaults, nil
	}
	file, err := os.Open(path)
	if os.IsNotExist(err) {
		return defaults, nil
	}
	if err != nil {
		return Config{}, fmt.Errorf("open AI settings: %w", err)
	}
	defer file.Close()
	decoder := json.NewDecoder(file)
	decoder.DisallowUnknownFields()
	var stored FileConfig
	if err := decoder.Decode(&stored); err != nil {
		return Config{}, fmt.Errorf("decode AI settings: %w", err)
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		return Config{}, fmt.Errorf("decode AI settings: expected one JSON object")
	}
	defaults.Enabled = stored.Enabled
	defaults.APIKey = strings.TrimSpace(stored.APIKey)
	defaults.Model = strings.TrimSpace(stored.Model)
	defaults.BaseURL = strings.TrimSpace(stored.BaseURL)
	return defaults, nil
}

func Build(config Config) (*ai.Service, string, error) {
	options := ai.ServiceOptions{Timeout: config.Timeout, CacheSize: config.CacheSize}
	if !config.Enabled {
		return nil, "disabled", nil
	}
	apiKey := strings.TrimSpace(config.APIKey)
	if apiKey == "" {
		apiKey = strings.TrimSpace(os.Getenv("ANTHROPIC_API_KEY"))
	}
	if apiKey == "" {
		return nil, "", fmt.Errorf("AI is enabled but ANTHROPIC_API_KEY is empty")
	}
	provider, err := anthropicai.New(anthropicai.Config{
		APIKey: apiKey, Model: config.Model, BaseURL: config.BaseURL,
		MaxTokens: config.MaxTokens, MaxRetries: config.MaxRetries,
	})
	if err != nil {
		return nil, "", fmt.Errorf("configure Anthropic-compatible dialogue: %w", err)
	}
	return ai.NewService(provider, options), "anthropic:" + config.Model, nil
}

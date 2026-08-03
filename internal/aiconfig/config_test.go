package aiconfig

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestBuildKeepsDisabledModeExplicitAndRejectsEnabledWithoutCredentials(t *testing.T) {
	t.Setenv("ANTHROPIC_API_KEY", "")
	service, mode, err := Build(Config{Enabled: false, Timeout: time.Second})
	if err != nil || service != nil || mode != "disabled" {
		t.Fatalf("disabled build = service:%v mode:%q err:%v", service, mode, err)
	}
	service, mode, err = Build(Config{Enabled: true, Model: "test", Timeout: time.Second})
	if err == nil || service != nil || mode != "" {
		t.Fatalf("enabled unconfigured build must fail = service:%v mode:%q err:%v", service, mode, err)
	}
}

func TestLoadFileOverridesUserFacingSettings(t *testing.T) {
	path := filepath.Join(t.TempDir(), "ai-settings.json")
	if err := os.WriteFile(path, []byte(`{"enabled":true,"api_key":"secret","model":"step-3.7-flash","base_url":"https://example.com/v1/messages"}`), 0o600); err != nil {
		t.Fatal(err)
	}
	config, err := LoadFile(path, Config{Model: "default", MaxTokens: 4096})
	if err != nil {
		t.Fatal(err)
	}
	if !config.Enabled || config.APIKey != "secret" || config.Model != "step-3.7-flash" || config.BaseURL != "https://example.com/v1/messages" || config.MaxTokens != 4096 {
		t.Fatalf("unexpected loaded config: %+v", config)
	}
}

func TestLoadFileRejectsUnknownFields(t *testing.T) {
	path := filepath.Join(t.TempDir(), "ai-settings.json")
	if err := os.WriteFile(path, []byte(`{"enabled":false,"unexpected":true}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := LoadFile(path, Config{}); err == nil {
		t.Fatal("unknown AI settings field was accepted")
	}
}

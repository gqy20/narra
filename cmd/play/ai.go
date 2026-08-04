package main

import (
	"flag"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	"time"

	"narra/internal/ai"
	"narra/internal/aiconfig"
)

type playAIProfile struct {
	Enabled    bool
	Model      string
	BaseURL    string
	MaxTokens  int
	Timeout    time.Duration
	MaxRetries int
}

type playAIFlags struct {
	dialogueEnabled    *bool
	dialogueModel      *string
	dialogueBaseURL    *string
	dialogueMaxTokens  *int
	dialogueTimeout    *time.Duration
	dialogueMaxRetries *int
	directorEnabled    *bool
	directorModel      *string
	directorBaseURL    *string
	directorMaxTokens  *int
	directorTimeout    *time.Duration
	directorMaxRetries *int
}

type playAIRuntime struct {
	dialogue     playAIProfile
	director     playAIProfile
	dialogueMode string
	directorMode string
}

func registerPlayAIFlags() playAIFlags {
	defaultEnabled := strings.TrimSpace(os.Getenv("ANTHROPIC_API_KEY")) != ""
	defaultModel := aiconfig.EnvironmentOrDefault("ANTHROPIC_MODEL", "claude-haiku-4-5")
	defaultBaseURL := os.Getenv("ANTHROPIC_BASE_URL")
	return playAIFlags{
		dialogueEnabled:    flag.Bool("ai-dialogue-enabled", defaultEnabled, "enable AI NPC dialogue"),
		dialogueModel:      flag.String("ai-dialogue-model", defaultModel, "Anthropic-compatible model used for NPC dialogue"),
		dialogueBaseURL:    flag.String("ai-dialogue-base-url", defaultBaseURL, "Anthropic-compatible API base URL for NPC dialogue"),
		dialogueMaxTokens:  flag.Int("ai-dialogue-max-tokens", 4096, "maximum output tokens for NPC dialogue"),
		dialogueTimeout:    flag.Duration("ai-dialogue-timeout", 60*time.Second, "maximum duration of an NPC dialogue request"),
		dialogueMaxRetries: flag.Int("ai-dialogue-max-retries", 1, "maximum SDK retries per NPC dialogue request"),
		directorEnabled:    flag.Bool("ai-director-enabled", defaultEnabled, "enable the AI world director"),
		directorModel:      flag.String("ai-director-model", defaultModel, "Anthropic-compatible model used by the world director"),
		directorBaseURL:    flag.String("ai-director-base-url", defaultBaseURL, "Anthropic-compatible API base URL for the world director"),
		directorMaxTokens:  flag.Int("ai-director-max-tokens", 4096, "maximum output tokens for a world director decision"),
		directorTimeout:    flag.Duration("ai-director-timeout", 60*time.Second, "maximum duration of a world director request"),
		directorMaxRetries: flag.Int("ai-director-max-retries", 1, "maximum SDK retries per world director request"),
	}
}

func profilesFromFlags(flags playAIFlags) (playAIProfile, playAIProfile) {
	return playAIProfile{
			Enabled: *flags.dialogueEnabled, Model: *flags.dialogueModel, BaseURL: *flags.dialogueBaseURL,
			MaxTokens: *flags.dialogueMaxTokens, Timeout: *flags.dialogueTimeout, MaxRetries: *flags.dialogueMaxRetries,
		}, playAIProfile{
			Enabled: *flags.directorEnabled, Model: *flags.directorModel, BaseURL: *flags.directorBaseURL,
			MaxTokens: *flags.directorMaxTokens, Timeout: *flags.directorTimeout, MaxRetries: *flags.directorMaxRetries,
		}
}

func buildPlayAIService(profile playAIProfile) (*ai.Service, string, error) {
	return aiconfig.Build(aiconfig.Config{
		Enabled: profile.Enabled, Model: profile.Model, BaseURL: profile.BaseURL,
		MaxTokens: int64(profile.MaxTokens), Timeout: profile.Timeout,
		MaxRetries: profile.MaxRetries, CacheSize: 128,
	})
}

func buildPlayAIRuntime(flags playAIFlags) (*playAIRuntime, *ai.Service, *ai.Service, error) {
	dialogueProfile, directorProfile := profilesFromFlags(flags)
	dialogue, dialogueMode, err := buildPlayAIService(dialogueProfile)
	if err != nil {
		return nil, nil, nil, fmt.Errorf("configure NPC dialogue: %w", err)
	}
	director, directorMode, err := buildPlayAIService(directorProfile)
	if err != nil {
		return nil, nil, nil, fmt.Errorf("configure world director: %w", err)
	}
	return &playAIRuntime{
		dialogue: dialogueProfile, director: directorProfile,
		dialogueMode: dialogueMode, directorMode: directorMode,
	}, dialogue, director, nil
}

func renderAIStatus(output io.Writer, game *terminalGame) {
	if game.ai == nil {
		fmt.Fprintln(output, "AI 配置：不可在当前会话中调整。")
		return
	}
	renderAIProfile(output, "NPC 对话", game.ai.dialogue, game.ai.dialogueMode)
	renderAIProfile(output, "世界导演", game.ai.director, game.ai.directorMode)
}

func renderAIProfile(output io.Writer, label string, profile playAIProfile, mode string) {
	state := "关闭"
	if profile.Enabled {
		state = "开启"
	}
	fmt.Fprintf(output, "%s：%s；模型 %s；超时 %s；最大输出 %d；重试 %d", label, state, profile.Model, profile.Timeout, profile.MaxTokens, profile.MaxRetries)
	if profile.BaseURL != "" {
		fmt.Fprintf(output, "；端点 %s", profile.BaseURL)
	}
	if mode != "" {
		fmt.Fprintf(output, "；运行模式 %s", mode)
	}
	fmt.Fprintln(output)
}

func runAICommand(output io.Writer, game *terminalGame, argument string) {
	if game.ai == nil {
		fmt.Fprintln(output, "当前会话没有可调整的 AI 运行时。")
		return
	}
	fields := strings.Fields(argument)
	if len(fields) == 0 || fields[0] == "status" {
		renderAIStatus(output, game)
		return
	}
	if len(fields) < 2 || (fields[0] != "dialogue" && fields[0] != "director") {
		renderAIUsage(output)
		return
	}
	kind := fields[0]
	profile := game.ai.dialogue
	if kind == "director" {
		profile = game.ai.director
	}
	switch fields[1] {
	case "on", "off":
		if len(fields) != 2 {
			renderAIUsage(output)
			return
		}
		profile.Enabled = fields[1] == "on"
	case "model", "base-url", "timeout", "max-tokens", "max-retries":
		if len(fields) != 3 {
			renderAIUsage(output)
			return
		}
		var err error
		switch fields[1] {
		case "model":
			profile.Model = fields[2]
		case "base-url":
			profile.BaseURL = fields[2]
		case "timeout":
			profile.Timeout, err = time.ParseDuration(fields[2])
		case "max-tokens":
			profile.MaxTokens, err = strconv.Atoi(fields[2])
		case "max-retries":
			profile.MaxRetries, err = strconv.Atoi(fields[2])
		}
		if err != nil {
			fmt.Fprintf(output, "AI 配置无效：%v\n", err)
			return
		}
	default:
		renderAIUsage(output)
		return
	}
	service, mode, err := buildPlayAIService(profile)
	if err != nil {
		fmt.Fprintf(output, "AI 配置未生效：%v\n", err)
		return
	}
	if kind == "dialogue" {
		game.ai.dialogue, game.ai.dialogueMode, game.dialogue = profile, mode, service
	} else {
		game.ai.director, game.ai.directorMode = profile, mode
		game.setWorldDirector(service)
	}
	fmt.Fprintln(output, "AI 配置已生效。")
	renderAIStatus(output, game)
}

func renderAIUsage(output io.Writer) {
	fmt.Fprintln(output, "用法：ai status；ai <dialogue|director> <on|off>；ai <dialogue|director> <model|base-url|timeout|max-tokens|max-retries> <值>")
}

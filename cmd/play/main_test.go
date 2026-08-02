package main

import (
	"bytes"
	"context"
	"errors"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"fantu/internal/ai"
	"fantu/internal/app"
	"fantu/internal/scenario"
)

type terminalDialogueProvider struct {
	calls int
}

type failingTerminalDialogueProvider struct{}

func (failingTerminalDialogueProvider) GenerateDialogue(context.Context, ai.GenerationRequest) (ai.DialogueDraft, ai.GenerationMetadata, error) {
	return ai.DialogueDraft{}, ai.GenerationMetadata{}, errors.New("provider failed")
}

func (p *terminalDialogueProvider) GenerateDialogue(context.Context, ai.GenerationRequest) (ai.DialogueDraft, ai.GenerationMetadata, error) {
	p.calls++
	return ai.DialogueDraft{
		Utterance: "消息可以谈，但我得先知道它从何而来。",
		Emotion:   "alert", DialogueAct: "question", ReferencedFacts: []string{},
	}, ai.GenerationMetadata{Model: "test"}, nil
}

func TestRunUsesExplicitActionsAndDoCommands(t *testing.T) {
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	session, err := app.NewSession(bundle, app.DefaultBlackwindPlayer("终端玩家"))
	if err != nil {
		t.Fatal(err)
	}
	var output bytes.Buffer
	if err := runGame(bytes.NewBufferString("actions\ndo 1\nquit\n"), &output, session, nil, "", false); err != nil {
		t.Fatal(err)
	}
	if session.View().Day != 1 {
		t.Fatalf("day = %d, want 1\n%s", session.View().Day, output.String())
	}
	if !bytes.Contains(output.Bytes(), []byte("可用行动")) || !bytes.Contains(output.Bytes(), []byte("已退出")) {
		t.Fatalf("unexpected output:\n%s", output.String())
	}
}

func TestRunAcceptsPowerShellBOM(t *testing.T) {
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	session, err := app.NewSession(bundle, app.DefaultBlackwindPlayer("终端玩家"))
	if err != nil {
		t.Fatal(err)
	}
	var output bytes.Buffer
	if err := runGame(bytes.NewBufferString("\ufeffquit\n"), &output, session, nil, "", false); err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(output.Bytes(), []byte("未知行动")) {
		t.Fatalf("BOM-prefixed command was not recognized:\n%s", output.String())
	}
}

func TestResolveActionNumberRejectsIDsAndValidatesNumber(t *testing.T) {
	actions := []app.AvailableAction{{ID: "wait"}}
	if _, err := resolveActionNumber("wait", actions); err == nil {
		t.Fatal("internal action ID was accepted as player input")
	}
	if _, err := resolveActionNumber("2", actions); err == nil {
		t.Fatal("out-of-range number unexpectedly succeeded")
	}
}

func TestDefaultViewLocalizesTermsAndHidesStableIDs(t *testing.T) {
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	session, err := app.NewSession(bundle, app.DefaultBlackwindPlayer("终端玩家"))
	if err != nil {
		t.Fatal(err)
	}
	var output bytes.Buffer
	renderView(&output, session.View(), false)
	text := output.String()
	for _, want := range []string{"序幕", "战力=2", "支援=0", "灵石=100", "信誉=3", "[传闻]"} {
		if !strings.Contains(text, want) {
			t.Errorf("default output does not contain %q:\n%s", want, text)
		}
	}
	for _, forbidden := range []string{"combat", "support", "spirit_stones", "credit", "F02", "verify:F02"} {
		if strings.Contains(text, forbidden) {
			t.Errorf("default output leaked %q:\n%s", forbidden, text)
		}
	}

	output.Reset()
	renderActions(&output, session.View().AvailableActions, true)
	if !strings.Contains(output.String(), "F02") || !strings.Contains(output.String(), "verify:F02") {
		t.Fatalf("debug output omitted stable IDs:\n%s", output.String())
	}
}

func TestDefaultViewLocalizesStatusAndInvestigationSource(t *testing.T) {
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	session, err := app.NewSession(bundle, app.DefaultBlackwindPlayer("终端玩家"))
	if err != nil {
		t.Fatal(err)
	}
	if _, err := session.Execute("verify:F02"); err != nil {
		t.Fatal(err)
	}
	var output bytes.Buffer
	renderView(&output, session.View(), false)
	if !strings.Contains(output.String(), "[已开始]") || strings.Contains(output.String(), "[started]") {
		t.Fatalf("status was not localized:\n%s", output.String())
	}
	if _, err := session.Execute("wait"); err != nil {
		t.Fatal(err)
	}
	output.Reset()
	renderView(&output, session.View(), false)
	if !strings.Contains(output.String(), "来源：亲自核验") || strings.Contains(output.String(), "player-investigation") {
		t.Fatalf("source was not localized:\n%s", output.String())
	}
}

func TestTerminalNavigationAndDialogueDoNotAdvanceWorld(t *testing.T) {
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	session, err := app.NewSession(bundle, app.DefaultBlackwindPlayer("终端玩家"))
	if err != nil {
		t.Fatal(err)
	}
	provider := &terminalDialogueProvider{}
	dialogue := ai.NewService(provider, ai.ServiceOptions{Timeout: time.Second, CacheSize: 4})
	var output bytes.Buffer
	commands := "look\npeople\ntalk 2\nmap\njournal\nquit\n"
	if err := runGame(bytes.NewBufferString(commands), &output, session, dialogue, "", false); err != nil {
		t.Fatal(err)
	}
	text := output.String()
	for _, want := range []string{"【白石坊市】", "【白石坊市 · 同地人物】", "魏无咎：", "【黑风谷周边地图】", "【行旅卷宗】"} {
		if !strings.Contains(text, want) {
			t.Errorf("terminal output does not contain %q:\n%s", want, text)
		}
	}
	if provider.calls != 1 || session.View().Day != 0 || session.View().Metrics.DecisionInputs != 0 {
		t.Fatalf("presentation changed world state: calls=%d view=%+v", provider.calls, session.View())
	}
}

func TestTerminalReportsModelFailureWithoutInventingDialogue(t *testing.T) {
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	for name, dialogue := range map[string]*ai.Service{
		"disabled": nil,
		"failed":   ai.NewService(failingTerminalDialogueProvider{}, ai.ServiceOptions{Timeout: time.Second}),
	} {
		t.Run(name, func(t *testing.T) {
			session, err := app.NewSession(bundle, app.DefaultBlackwindPlayer("终端玩家"))
			if err != nil {
				t.Fatal(err)
			}
			var output bytes.Buffer
			if err := runGame(bytes.NewBufferString("talk 2\nquit\n"), &output, session, dialogue, "", false); err != nil {
				t.Fatal(err)
			}
			text := output.String()
			if !strings.Contains(text, "人物对话未启用") && !strings.Contains(text, "对话生成失败") {
				t.Fatalf("model failure was hidden:\n%s", text)
			}
			if strings.Contains(text, "魏无咎：“") || session.View().Day != 0 {
				t.Fatalf("failure produced invented dialogue or changed state:\n%s", text)
			}
		})
	}
}

func TestTerminalCanCompleteAndReplayAFullJourney(t *testing.T) {
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	session, err := app.NewSession(bundle, app.DefaultBlackwindPlayer("完整通关玩家"))
	if err != nil {
		t.Fatal(err)
	}
	savePath := filepath.Join(t.TempDir(), "terminal-complete.json")
	commands := strings.Join([]string{
		"actions", "do 1", "wait complete", "actions", "do 14", "go 青岚门驻地",
		"actions", "do 3", "wait next", "actions", "do 3", "wait next",
		"actions", "do 3", "wait next", "wait next", "wait next",
	}, "\n") + "\n"
	var output bytes.Buffer
	if err := runGame(bytes.NewBufferString(commands), &output, session, nil, savePath, true); err != nil {
		t.Fatal(err)
	}
	view := session.View()
	if !view.Resolved || view.Day != 21 || view.Location.ID != "L02" || !strings.Contains(output.String(), "局势结束") {
		t.Fatalf("terminal journey did not finish: view=%+v\n%s", view, output.String())
	}
	if view.Player.Resources["credit"] != 4 || view.Player.Resources["support"] != 2 || len(view.CausalThreads) == 0 || view.Metrics.VisibleDecisionChanges != 2 {
		t.Fatalf("terminal journey skipped its intended trust route: view=%+v", view)
	}
	replayed, err := app.LoadFile(bundle, savePath)
	if err != nil {
		t.Fatal(err)
	}
	if replayed.View().Outcome != view.Outcome || replayed.View().Metrics.DecisionInputs != view.Metrics.DecisionInputs {
		t.Fatalf("replayed journey differs: got=%+v want=%+v", replayed.View(), view)
	}
}

func TestTerminalTravelUsesMapNumberOrPublicName(t *testing.T) {
	for _, command := range []string{"go 2\nquit\n", "go 青岚门驻地\nquit\n"} {
		bundle, err := scenario.Load("../../data/blackwind")
		if err != nil {
			t.Fatal(err)
		}
		session, err := app.NewSession(bundle, app.DefaultBlackwindPlayer("终端玩家"))
		if err != nil {
			t.Fatal(err)
		}
		var output bytes.Buffer
		if err := runGame(bytes.NewBufferString(command), &output, session, nil, "", false); err != nil {
			t.Fatal(err)
		}
		if session.View().Location.ID != "L02" || session.View().Day != 1 {
			t.Fatalf("travel command %q failed: view=%+v\n%s", command, session.View(), output.String())
		}
	}
}

func TestBareNumbersAndInternalActionIDsAreNotCommands(t *testing.T) {
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	session, err := app.NewSession(bundle, app.DefaultBlackwindPlayer("终端玩家"))
	if err != nil {
		t.Fatal(err)
	}
	var output bytes.Buffer
	if err := runGame(bytes.NewBufferString("1\nverify:F02\nquit\n"), &output, session, nil, "", false); err != nil {
		t.Fatal(err)
	}
	if session.View().Day != 0 || !strings.Contains(output.String(), "不能直接输入编号") || strings.Count(output.String(), "未知命令") != 1 {
		t.Fatalf("non-command input was not rejected:\n%s", output.String())
	}
}

func TestWaitAdvancesOneDayAndWaitNextIsExplicit(t *testing.T) {
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	for _, test := range []struct {
		command string
		day     int
	}{{"wait\nquit\n", 1}, {"wait next\nquit\n", 8}} {
		session, err := app.NewSession(bundle, app.DefaultBlackwindPlayer("等待测试"))
		if err != nil {
			t.Fatal(err)
		}
		var output bytes.Buffer
		if err := runGame(bytes.NewBufferString(test.command), &output, session, nil, "", false); err != nil {
			t.Fatal(err)
		}
		if session.View().Day != test.day {
			t.Fatalf("command %q reached day %d, want %d\n%s", test.command, session.View().Day, test.day, output.String())
		}
	}
}

func TestTerminalPresentationExplainsPreparationAndLoss(t *testing.T) {
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	session, err := app.NewSession(bundle, app.DefaultBlackwindPlayer("复盘测试"))
	if err != nil {
		t.Fatal(err)
	}
	var output bytes.Buffer
	renderJournal(&output, session.View(), false)
	if !strings.Contains(output.String(), "综合准备分：2 / 胜算基线 6") || !strings.Contains(output.String(), "计分来源") || !strings.Contains(output.String(), "参赛条件") {
		t.Fatalf("preparation remains opaque:\n%s", output.String())
	}
	output.Reset()
	for !session.View().Resolved {
		if _, err := session.Execute("wait"); err != nil {
			t.Fatal(err)
		}
	}
	renderView(&output, session.View(), false)
	if !strings.Contains(output.String(), "胜负复盘") || !strings.Contains(output.String(), "没有解瘴丹") {
		t.Fatalf("ending omitted actionable review:\n%s", output.String())
	}
}

func TestActionCategoriesUseScopedDoNumbersAndHideTimeActions(t *testing.T) {
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	session, err := app.NewSession(bundle, app.DefaultBlackwindPlayer("分类测试"))
	if err != nil {
		t.Fatal(err)
	}
	var output bytes.Buffer
	renderActionsCategory(&output, session.View().AvailableActions, "出行", false)
	text := output.String()
	if !strings.Contains(text, "前往青岚门驻地") || strings.Contains(text, "等待局势变化") || !strings.Contains(text, "1. 前往青岚门驻地") {
		t.Fatalf("travel category output is not actionable:\n%s", text)
	}
	output.Reset()
	if err := runGame(bytes.NewBufferString("actions travel\ndo 1\nquit\n"), &output, session, nil, "", false); err != nil {
		t.Fatal(err)
	}
	if session.View().Location.ID != "L02" {
		t.Fatalf("filtered action number did not execute displayed travel action: %+v\n%s", session.View(), output.String())
	}
}

func TestDoRequiresFreshActionMenu(t *testing.T) {
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	session, err := app.NewSession(bundle, app.DefaultBlackwindPlayer("编号测试"))
	if err != nil {
		t.Fatal(err)
	}
	var output bytes.Buffer
	if err := runGame(bytes.NewBufferString("do 1\nactions\ndo 1\ndo 1\nquit\n"), &output, session, nil, "", false); err != nil {
		t.Fatal(err)
	}
	if session.View().Day != 1 || strings.Count(output.String(), "行动目录尚未显示或已经变化") != 2 {
		t.Fatalf("stale action menu was accepted:\n%s", output.String())
	}
}

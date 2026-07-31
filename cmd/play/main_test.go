package main

import (
	"bytes"
	"strings"
	"testing"

	"fantu/internal/app"
	"fantu/internal/scenario"
)

func TestRunAcceptsActionNumberAndQuit(t *testing.T) {
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	session, err := app.NewSession(bundle, defaultPlayer("终端玩家"))
	if err != nil {
		t.Fatal(err)
	}
	var output bytes.Buffer
	if err := run(bytes.NewBufferString("1\nquit\n"), &output, session, "", false); err != nil {
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
	session, err := app.NewSession(bundle, defaultPlayer("终端玩家"))
	if err != nil {
		t.Fatal(err)
	}
	var output bytes.Buffer
	if err := run(bytes.NewBufferString("\ufeffquit\n"), &output, session, "", false); err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(output.Bytes(), []byte("未知行动")) {
		t.Fatalf("BOM-prefixed command was not recognized:\n%s", output.String())
	}
}

func TestResolveActionAcceptsIDAndValidatesNumber(t *testing.T) {
	actions := []app.AvailableAction{{ID: "wait"}}
	if got, err := resolveAction("wait", actions); err != nil || got != "wait" {
		t.Fatalf("resolveAction(wait) = %q, %v", got, err)
	}
	if _, err := resolveAction("2", actions); err == nil {
		t.Fatal("out-of-range number unexpectedly succeeded")
	}
}

func TestDefaultViewLocalizesTermsAndHidesStableIDs(t *testing.T) {
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	session, err := app.NewSession(bundle, defaultPlayer("终端玩家"))
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
	renderView(&output, session.View(), true)
	if !strings.Contains(output.String(), "F02") || !strings.Contains(output.String(), "verify:F02") {
		t.Fatalf("debug output omitted stable IDs:\n%s", output.String())
	}
}

func TestDefaultViewLocalizesStatusAndInvestigationSource(t *testing.T) {
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	session, err := app.NewSession(bundle, defaultPlayer("终端玩家"))
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

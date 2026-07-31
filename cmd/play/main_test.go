package main

import (
	"bytes"
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
	if err := run(bytes.NewBufferString("1\nquit\n"), &output, session, ""); err != nil {
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
	if err := run(bytes.NewBufferString("\ufeffquit\n"), &output, session, ""); err != nil {
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

package app

import (
	"strings"
	"testing"

	"fantu/internal/scenario"
)

func loadTianqiSession(t *testing.T) *Session {
	t.Helper()
	bundle, err := scenario.Load("../../data/tianqi")
	if err != nil {
		t.Fatalf("load tianqi scenario: %v", err)
	}
	session, err := NewSession(bundle, DefaultPlayer(bundle, "无名抄手"))
	if err != nil {
		t.Fatalf("new tianqi session: %v", err)
	}
	return session
}

func TestTianqiPlayerCanProtectE10BeforeGreyNetworkInterception(t *testing.T) {
	session := loadTianqiSession(t)
	if _, err := session.Execute("move:L03"); err != nil {
		t.Fatalf("move to inquiry office: %v", err)
	}
	for session.View().Day < 11 {
		if _, err := session.Execute("wait:next"); err != nil {
			t.Fatalf("advance to E10 window: %v", err)
		}
	}
	if _, err := session.Execute("move:L06"); err != nil {
		t.Fatalf("move to study: %v", err)
	}
	if actionWithID(session.View().AvailableActions, "route:e10:protect-original") == nil {
		t.Fatalf("E10 protection action is unavailable on day %d", session.View().Day)
	}
	view, err := session.Execute("route:e10:protect-original")
	if err != nil {
		t.Fatalf("protect E10: %v", err)
	}
	state := session.engine.State()
	if state.Items["e10_statement"] != state.Player.ID || state.WorldFlag("zhou_intercepted") || !state.WorldFlag("zhou_protected") {
		t.Fatalf("E10 protection did not preempt interception: owner=%s intercepted=%v protected=%v", state.Items["e10_statement"], state.WorldFlag("zhou_intercepted"), state.WorldFlag("zhou_protected"))
	}
	if itemAmount(view.Player.Items, "e10_statement") != 1 || view.Player.Resources["evidence"] != 3 || view.Player.Resources["exposure"] != 2 {
		t.Fatalf("unexpected E10 player result: player=%+v", view.Player)
	}
}

func TestTianqiPlayerCanPublishBoundedFinalRecord(t *testing.T) {
	session := loadTianqiSession(t)
	if _, err := session.Execute("move:L04"); err != nil {
		t.Fatalf("move to news shop: %v", err)
	}
	for actionWithID(session.View().AvailableActions, "route:record:bounded") == nil && session.View().Day < 12 {
		if _, err := session.Execute("wait:next"); err != nil {
			t.Fatalf("advance to writing window: %v", err)
		}
	}
	if actionWithID(session.View().AvailableActions, "route:record:bounded") == nil {
		state := session.engine.State()
		t.Fatalf("bounded record action is unavailable on day %d: N07=%s arc=%s actions=%v", session.View().Day, state.NPCs["N07"].Location, state.StoryStates["final_record"], actionIDs(session.View().AvailableActions))
	}
	view, err := session.Execute("route:record:bounded")
	if err != nil {
		t.Fatalf("publish bounded record: %v", err)
	}
	state := session.engine.State()
	if !state.WorldFlag("bounded_record_public") || !state.WorldFlag("systemic_caveat") || !state.ActorFlag(state.Player.ID, "prepared") {
		t.Fatalf("bounded record flags missing: world=%v actor=%v", state.WorldFlags, state.ActorFlags[state.Player.ID])
	}
	if view.Player.Resources["evidence"] != 3 || view.Player.Resources["allies"] != 2 {
		t.Fatalf("bounded record resources = %+v", view.Player.Resources)
	}
	for !view.Resolved {
		view, err = session.Execute("wait:next")
		if err != nil {
			t.Fatalf("advance to bounded record outcome: %v", err)
		}
	}
	if !strings.Contains(view.Outcome, "有限会勘报告") || !strings.Contains(view.Outcome, "不能推出唯一爆炸成因") {
		t.Fatalf("bounded record outcome = %q", view.Outcome)
	}
}

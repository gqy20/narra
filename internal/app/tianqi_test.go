package app

import (
	"strings"
	"testing"

	"fantu/internal/scenario"
)

func loadTianqiSession(t *testing.T) *Session {
	return loadTianqiSessionWithExposure(t, 0)
}

func loadTianqiSessionWithExposure(t *testing.T, exposure int) *Session {
	t.Helper()
	bundle, err := scenario.Load("../../data/tianqi")
	if err != nil {
		t.Fatalf("load tianqi scenario: %v", err)
	}
	player := DefaultPlayer(bundle, "无名抄手")
	player.Resources["exposure"] = exposure
	session, err := NewSession(bundle, player)
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

func TestTianqiWitnessProtectionChangesRegisterChoices(t *testing.T) {
	session := loadTianqiSession(t)
	if _, err := session.Execute("move:L02"); err != nil {
		t.Fatalf("move to apothecary: %v", err)
	}
	if _, err := session.Execute("wait:next"); err != nil {
		t.Fatalf("advance to witness window: %v", err)
	}
	if actionWithID(session.View().AvailableActions, "route:e07:protect") == nil {
		state := session.engine.State()
		t.Fatalf("witness protection route unavailable on day %d at %s: story=%v belief=%+v N03=%s actions=%v", state.Day, state.Player.Location, state.StoryStates, state.Player.Beliefs["F02"], state.NPCs["N03"].Location, actionIDs(session.View().AvailableActions))
	}
	if _, err := session.Execute("route:e07:protect"); err != nil {
		t.Fatalf("protect witness: %v", err)
	}
	actions := session.View().AvailableActions
	if actionWithID(actions, "route:e08:verify-protected") == nil || actionWithID(actions, "route:e08:publish-redacted") == nil {
		t.Fatalf("protected register choices unavailable: %v", actionIDs(actions))
	}
	if actionWithID(actions, "route:e08:verify") != nil || actionWithID(actions, "route:e08:publish") != nil {
		t.Fatalf("unsafe register choices remained available after protection: %v", actionIDs(actions))
	}
	view, err := session.Execute("route:e08:verify-protected")
	if err != nil {
		t.Fatalf("verify protected register: %v", err)
	}
	state := session.engine.State()
	if !state.WorldFlag("protected_register_network") || state.WorldFlag("witness_identity_exposed") || state.WorldFlag("witness_pressured") {
		t.Fatalf("protected register state = protected:%v exposed:%v pressured:%v", state.WorldFlag("protected_register_network"), state.WorldFlag("witness_identity_exposed"), state.WorldFlag("witness_pressured"))
	}
	if view.Player.Resources["evidence"] != 4 || view.Player.Resources["allies"] != 4 || view.Player.Resources["exposure"] != 0 {
		t.Fatalf("protected register resources = %+v", view.Player.Resources)
	}
}

func TestTianqiShowsConcurrentRouteDeadlines(t *testing.T) {
	session := loadTianqiSession(t)
	if _, err := session.Execute("move:L02"); err != nil {
		t.Fatalf("move to apothecary: %v", err)
	}
	if _, err := session.Execute("wait:next"); err != nil {
		t.Fatalf("advance to concurrent route window: %v", err)
	}
	view := session.View()
	progressByID := make(map[string]RouteProgress, len(view.RouteProgresses))
	for _, progress := range view.RouteProgresses {
		progressByID[progress.ID] = progress
	}
	for _, routeID := range []string{"e01", "e07", "e08"} {
		if _, ok := progressByID[routeID]; !ok {
			t.Fatalf("concurrent route %s missing: %+v", routeID, view.RouteProgresses)
		}
	}
	if view.RouteProgress == nil || view.RouteProgress.ID != view.RouteProgresses[0].ID {
		t.Fatalf("legacy route progress does not mirror first concurrent route: legacy=%+v all=%+v", view.RouteProgress, view.RouteProgresses)
	}
}

func TestTianqiActionWarnsBeforeCrossingExposureThreshold(t *testing.T) {
	session := loadTianqiSessionWithExposure(t, 1)
	if _, err := session.Execute("move:L02"); err != nil {
		t.Fatalf("move to apothecary: %v", err)
	}
	if _, err := session.Execute("wait:next"); err != nil {
		t.Fatalf("advance to register window: %v", err)
	}
	action := actionWithID(session.View().AvailableActions, "route:e08:publish")
	if action == nil || !containsMessage(action.Warnings, "暴露：1 → 3") || !containsMessage(action.Warnings, "行踪跟踪") {
		t.Fatalf("exposure threshold warning = %+v", action)
	}
}

func TestTianqiUnredactedRegisterTriggersSourcePressure(t *testing.T) {
	session := loadTianqiSession(t)
	if _, err := session.Execute("move:L02"); err != nil {
		t.Fatalf("move to apothecary: %v", err)
	}
	if _, err := session.Execute("wait:next"); err != nil {
		t.Fatalf("advance to register window: %v", err)
	}
	if actionWithID(session.View().AvailableActions, "route:e08:publish") == nil {
		state := session.engine.State()
		t.Fatalf("unredacted register route unavailable on day %d at %s: story=%v N08=%s actions=%v", state.Day, state.Player.Location, state.StoryStates, state.NPCs["N08"].Location, actionIDs(session.View().AvailableActions))
	}
	view, err := session.Execute("route:e08:publish")
	if err != nil {
		t.Fatalf("publish unredacted register: %v", err)
	}
	for session.View().Day < 4 && !session.engine.State().WorldFlag("witness_pressured") {
		view, err = session.Execute("wait:next")
		if err != nil {
			t.Fatalf("advance to source tracing response: %v", err)
		}
	}
	state := session.engine.State()
	if !state.WorldFlag("witness_identity_exposed") || !state.WorldFlag("witness_pressured") || state.WorldFlag("protected_register_network") {
		t.Fatalf("unredacted register state = protected:%v exposed:%v pressured:%v", state.WorldFlag("protected_register_network"), state.WorldFlag("witness_identity_exposed"), state.WorldFlag("witness_pressured"))
	}
	if view.Player.Resources["authority"] != 2 || view.Player.Resources["exposure"] != 2 {
		t.Fatalf("unredacted register resources = %+v", view.Player.Resources)
	}
}

func TestTianqiOriginalLedgerChainCanExposeAndCorrelateForgery(t *testing.T) {
	session := loadTianqiSession(t)
	steps := []string{"route:e01:keep-original", "move:L03"}
	for _, actionID := range steps {
		if actionWithID(session.View().AvailableActions, actionID) == nil {
			t.Fatalf("ledger action %s unavailable on day %d at %s: %v", actionID, session.View().Day, session.View().Location.ID, actionIDs(session.View().AvailableActions))
		}
		if _, err := session.Execute(actionID); err != nil {
			t.Fatalf("execute %s: %v", actionID, err)
		}
	}
	for session.View().Day < 3 {
		if _, err := session.Execute("wait:next"); err != nil {
			t.Fatalf("advance to official delivery: %v", err)
		}
	}
	for _, actionID := range []string{"route:e01:official", "move:L06"} {
		if actionWithID(session.View().AvailableActions, actionID) == nil {
			t.Fatalf("ledger action %s unavailable on day %d at %s: %v", actionID, session.View().Day, session.View().Location.ID, actionIDs(session.View().AvailableActions))
		}
		if _, err := session.Execute(actionID); err != nil {
			t.Fatalf("execute %s: %v", actionID, err)
		}
	}
	for session.View().Day < 8 {
		if _, err := session.Execute("wait:next"); err != nil {
			t.Fatalf("advance to format check: %v", err)
		}
	}
	if _, err := session.Execute("route:e09:format-check"); err != nil {
		t.Fatalf("verify E09 format: %v", err)
	}
	for session.View().Day < 12 {
		if _, err := session.Execute("wait:next"); err != nil {
			t.Fatalf("advance to ledger correlation: %v", err)
		}
	}
	if actionWithID(session.View().AvailableActions, "route:e10:correlate-and-protect") == nil {
		t.Fatalf("ledger correlation route unavailable on day %d: %v", session.View().Day, actionIDs(session.View().AvailableActions))
	}
	view, err := session.Execute("route:e10:correlate-and-protect")
	if err != nil {
		t.Fatalf("correlate and protect E10: %v", err)
	}
	state := session.engine.State()
	if !state.WorldFlag("e09_format_verified") || !state.WorldFlag("forged_ledger_exposed") || !state.WorldFlag("ledger_chain_correlated") || state.Items["e10_statement"] != state.Player.ID {
		t.Fatalf("ledger chain state: flags=%v E10=%s", state.WorldFlags, state.Items["e10_statement"])
	}
	for !view.Resolved {
		view, err = session.Execute("wait:next")
		if err != nil {
			t.Fatalf("advance to correlated outcome: %v", err)
		}
	}
	if !strings.Contains(view.Outcome, "形成独立串证") || !strings.Contains(view.Outcome, "不把它冒充为爆炸成因") {
		t.Fatalf("correlated ledger outcome = %q", view.Outcome)
	}
}

func TestTianqiE01FormatCheckUnlocksOfficialForgeryExposure(t *testing.T) {
	session := loadTianqiSession(t)
	for _, actionID := range []string{"route:e01:keep-original", "move:L03"} {
		if _, err := session.Execute(actionID); err != nil {
			t.Fatalf("execute %s: %v", actionID, err)
		}
	}
	for session.View().Day < 3 {
		if _, err := session.Execute("wait:next"); err != nil {
			t.Fatalf("advance to official delivery: %v", err)
		}
	}
	for _, actionID := range []string{"route:e01:official", "move:L06"} {
		if _, err := session.Execute(actionID); err != nil {
			t.Fatalf("execute %s: %v", actionID, err)
		}
	}
	for session.View().Day < 8 {
		if _, err := session.Execute("wait:next"); err != nil {
			t.Fatalf("advance to format check: %v", err)
		}
	}
	if _, err := session.Execute("route:e09:format-check"); err != nil {
		t.Fatalf("verify E09 format: %v", err)
	}
	if _, err := session.Execute("move:L03"); err != nil {
		t.Fatalf("return to inquiry office: %v", err)
	}
	for session.View().Day < 11 {
		if _, err := session.Execute("wait:next"); err != nil {
			t.Fatalf("advance to official exposure: %v", err)
		}
	}
	if actionWithID(session.View().AvailableActions, "route:final:expose-forgery") == nil {
		t.Fatalf("official forgery exposure unavailable: %v", actionIDs(session.View().AvailableActions))
	}
	if _, err := session.Execute("route:final:expose-forgery"); err != nil {
		t.Fatalf("expose forged ledger: %v", err)
	}
	if !session.engine.State().WorldFlag("forged_ledger_exposed") {
		t.Fatal("official forgery exposure did not set world consequence")
	}
}

func TestTianqiExposurePressureOpensWitnessResponse(t *testing.T) {
	lowSession := loadTianqiSessionWithExposure(t, 2)
	for lowSession.View().Day < 2 && !lowSession.engine.State().WorldFlag("exposure_watched") {
		if _, err := lowSession.Execute("wait:next"); err != nil {
			t.Fatalf("trigger exposure watch: %v", err)
		}
	}
	state := lowSession.engine.State()
	if !state.WorldFlag("exposure_watched") || state.WorldFlag("source_inquiry_open") {
		t.Fatalf("low exposure flags = %v", state.WorldFlags)
	}

	session := loadTianqiSessionWithExposure(t, 4)
	for session.View().Day < 3 && !session.engine.State().WorldFlag("source_inquiry_open") {
		if _, err := session.Execute("wait:next"); err != nil {
			t.Fatalf("trigger source inquiry: %v", err)
		}
	}
	state = session.engine.State()
	if !state.WorldFlag("source_inquiry_open") || state.Opportunities["answer_source_inquiry"] == "" || state.Opportunities["relocate_witness"] == "" {
		t.Fatalf("medium exposure state: flags=%v opportunities=%v", state.WorldFlags, state.Opportunities)
	}
	if _, err := session.Execute("move:L02"); err != nil {
		t.Fatalf("move to witness relocation: %v", err)
	}
	if actionWithID(session.View().AvailableActions, "opportunity:relocate-witness") == nil {
		t.Fatalf("witness relocation unavailable: %v", actionIDs(session.View().AvailableActions))
	}
	view, err := session.Execute("opportunity:relocate-witness")
	if err != nil {
		t.Fatalf("relocate witness: %v", err)
	}
	state = session.engine.State()
	if !state.WorldFlag("witness_relocated") || !state.WorldFlag("witness_protected") || state.NPCs["N03"].Location != "L07" || state.StoryStates["witness_route"] != "protected" || state.Opportunities["answer_source_inquiry"] != "" || state.Opportunities["relocate_witness"] != "" {
		t.Fatalf("witness response did not resolve both opportunities: flags=%v opportunities=%v", state.WorldFlags, state.Opportunities)
	}
	if view.Player.Resources["allies"] != 0 || view.Player.Resources["exposure"] != 3 {
		t.Fatalf("witness relocation resources = %+v", view.Player.Resources)
	}
}

func TestTianqiHighExposureBlocksFormalPublication(t *testing.T) {
	session := loadTianqiSessionWithExposure(t, 6)
	if _, err := session.Execute("move:L04"); err != nil {
		t.Fatalf("move to news shop: %v", err)
	}
	for session.View().Day < 9 || !session.engine.State().WorldFlag("publication_blocked") {
		if _, err := session.Execute("wait:next"); err != nil {
			t.Fatalf("advance to high exposure publication window: %v", err)
		}
	}
	actions := session.View().AvailableActions
	if actionWithID(actions, "route:record:bounded") != nil || actionWithID(actions, "route:record:accusatory") != nil {
		t.Fatalf("formal publication remained available under high exposure: %v", actionIDs(actions))
	}
	if actionWithID(actions, "route:record:private") == nil || actionWithID(actions, "route:record:anonymous") == nil {
		t.Fatalf("high exposure alternatives unavailable: %v", actionIDs(actions))
	}
	view, err := session.Execute("route:record:anonymous")
	if err != nil {
		t.Fatalf("circulate anonymous fragments: %v", err)
	}
	state := session.engine.State()
	if !state.WorldFlag("anonymous_record_circulating") || !state.ActorFlag(state.Player.ID, "player_anonymous_record") || state.StoryStates["final_record"] != "anonymous_circulation" {
		t.Fatalf("anonymous publication state: world=%v actor=%v story=%v", state.WorldFlags, state.ActorFlags[state.Player.ID], state.StoryStates)
	}
	if view.Player.Resources["exposure"] != 5 || view.Player.Resources["allies"] != 1 || view.Player.Resources["authority"] != 1 {
		t.Fatalf("anonymous publication resources = %+v", view.Player.Resources)
	}
}

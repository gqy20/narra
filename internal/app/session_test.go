package app

import (
	"bytes"
	"encoding/json"
	"path/filepath"
	"reflect"
	"regexp"
	"strings"
	"testing"

	"narra/internal/domain"
	"narra/internal/scenario"
)

func testSession(t *testing.T) *Session {
	t.Helper()
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	session, err := NewSession(bundle, domain.PlayerConfig{
		ID: "P00", Name: "测试玩家", Location: "L01",
		Resources: map[string]int{"combat": 2, "support": 0, "spirit_stones": 100, "credit": 3},
		Items:     []string{"healing_pill"},
		Beliefs: []domain.Belief{{
			FactID: "F02", Claim: "青髓芝将在第24天成熟", Confidence: 1, Source: "坊市传言",
		}},
	})
	if err != nil {
		t.Fatal(err)
	}
	return session
}

func TestDefaultPlayerComesFromContentAndIsCloned(t *testing.T) {
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	player := DefaultPlayer(bundle, "自定义姓名")
	player.Resources["combat"] = 99
	player.Items[0] = "changed"
	if player.Name != "自定义姓名" || bundle.DefaultPlayer.Name != "无名散修" || bundle.DefaultPlayer.Resources["combat"] != 2 || bundle.DefaultPlayer.Items[0] != "healing_pill" {
		t.Fatalf("default player was not independently cloned: player=%+v template=%+v", player, bundle.DefaultPlayer)
	}
}

func TestViewOnlyExposesPlayerKnowledge(t *testing.T) {
	session := testSession(t)
	view := session.View()
	if len(view.KnownFacts) != 1 || view.KnownFacts[0].FactID != "F02" {
		t.Fatalf("known facts = %+v", view.KnownFacts)
	}
	encoded, err := json.Marshal(view)
	if err != nil {
		t.Fatal(err)
	}
	for _, forbidden := range []string{"\"truth\"", "\"strategies\"", "\"score\"", "\"world_flags\""} {
		if bytes.Contains(encoded, []byte(forbidden)) {
			t.Fatalf("player view leaked private field %s: %s", forbidden, encoded)
		}
	}
}

func TestInitialCatalogIsDynamicAndRouteAware(t *testing.T) {
	view := testSession(t).View()
	ids := actionIDs(view.AvailableActions)
	for _, want := range []string{"verify:F02", "buy:M01:antidote", "move:L02", "move:L03", "cultivate", "wait:next"} {
		if !ids[want] {
			t.Errorf("missing action %s in %#v", want, ids)
		}
	}
	if ids["move:L04"] {
		t.Fatal("locked route to L04 should not be available")
	}
}

func TestWorldMapOnlyExposesPublicRouteState(t *testing.T) {
	view := testSession(t).View()
	if len(view.WorldMap.Locations) != 5 || len(view.WorldMap.Routes) == 0 {
		t.Fatalf("world map is incomplete: %+v", view.WorldMap)
	}
	currentCount := 0
	for _, location := range view.WorldMap.Locations {
		if location.Name == "" || location.SceneKey == "" || location.Description == "" || location.X <= 0 || location.Y <= 0 {
			t.Fatalf("map location lacks presentation data: %+v", location)
		}
		if location.Current {
			currentCount++
			if location.ID != "L01" || location.ActorCount != len(view.KnownActors) {
				t.Fatalf("current map location = %+v", location)
			}
		} else if location.ID == "L02" {
			if location.ActorCount != len(view.WorldMap.Actors) {
				t.Fatalf("tracked core actor count = %+v", location)
			}
		} else if location.ActorCount != 0 {
			t.Fatalf("map leaked an untracked remote actor count: %+v", location)
		}
	}
	if currentCount != 1 {
		t.Fatalf("current map location count = %d", currentCount)
	}
	available := mapRoute(view.WorldMap.Routes, "L01", "L02")
	if available == nil || available.Status != "available" || available.ActionID != "move:L02" {
		t.Fatalf("available route = %+v", available)
	}
	blocked := mapRoute(view.WorldMap.Routes, "L01", "L04")
	if blocked == nil || blocked.Status != "blocked" || blocked.ActionID != "" || !containsMessage(blocked.Blockers, "解瘴丹") || !containsMessage(blocked.Blockers, "入口") {
		t.Fatalf("blocked route = %+v", blocked)
	}
}

func TestWorldMapExposesCoreActorPlansWithoutPrivateStrategyData(t *testing.T) {
	session := testSession(t)
	view := session.View()
	if len(view.WorldMap.Actors) != 3 {
		t.Fatalf("tracked actor plans = %+v", view.WorldMap.Actors)
	}
	for _, actorID := range []string{"N03", "N06", "N09"} {
		plan := mapActorPlan(view.WorldMap.Actors, actorID)
		if plan == nil || plan.Name == "" || plan.LocationID == "" || plan.PublicGoal == "" || plan.Plan == "" || plan.Reason == "" {
			t.Fatalf("actor %s lacks a visible plan: %+v", actorID, plan)
		}
	}
	encoded, err := json.Marshal(view.WorldMap.Actors)
	if err != nil {
		t.Fatal(err)
	}
	for _, forbidden := range []string{"strategies", "score", "counterfactuals"} {
		if bytes.Contains(encoded, []byte(forbidden)) {
			t.Fatalf("actor plans leaked private field %s: %s", forbidden, encoded)
		}
	}
}

func TestActorPlanPresentationComesFromContent(t *testing.T) {
	session := testSession(t)
	if got := session.planFlagLabel(domain.Condition{Type: "flag", Key: "qinglan_review"}); got != "青岚门进入公开审核" {
		t.Fatalf("public flag label = %q", got)
	}
	if got := session.planFlagLabel(domain.Condition{Type: "flag", Key: "rumor_public"}); got != "局势条件已经发生变化" {
		t.Fatalf("private flag fallback = %q", got)
	}
	config := session.actorConfig("N09")
	strategy := strategyByID(config.Strategies, "N09-spread-false-date")
	if !config.TrackPublicPlan || config.PublicGoal != "维护宗门审核与内部秩序" || strategy.PublicDescription != "把一则成熟日期传闻带入坊市" {
		t.Fatalf("content-backed actor plan = config %+v strategy %+v", config, strategy)
	}
}

func TestActionMetadataAndPublicProfilesArePlayerFacing(t *testing.T) {
	session := testSession(t)
	view := session.View()
	if len(view.KnownActors) == 0 {
		t.Fatal("no visible actors")
	}
	for _, actor := range view.KnownActors {
		if actor.PublicProfile == "" || actor.PublicRole == "" || len(actor.PublicFocus) == 0 || actor.PublicRisk == "" {
			t.Fatalf("invalid public profile: %+v", actor)
		}
	}
	encoded, err := json.Marshal(view)
	if err != nil {
		t.Fatal(err)
	}
	for _, config := range session.bundle.NPCs {
		if config.Goal != "" && strings.Contains(string(encoded), config.Goal) {
			t.Fatalf("player view leaked hidden goal for %s", config.Name)
		}
	}
	for _, action := range view.AvailableActions {
		if action.Kind == "" {
			t.Fatalf("action missing kind: %+v", action)
		}
		if action.Timing == "" || len(action.ExpectedOutcomes) == 0 {
			t.Fatalf("action missing decision summary: %+v", action)
		}
		if len(action.KnownConditions) == 0 && len(action.Unknowns) == 0 {
			t.Fatalf("action does not distinguish known conditions from uncertainty: %+v", action)
		}
		if action.ID == "wait:next" && action.CompletionDay != 0 {
			t.Fatalf("open-ended advance has a misleading completion day: %+v", action)
		}
		if action.ID != "wait:next" && action.CompletionDay <= view.Day {
			t.Fatalf("action has invalid completion day: %+v", action)
		}
		if action.Kind == "tell" && (action.TargetID == "" || action.TargetName == "" || action.FactID == "" || action.FactClaim == "") {
			t.Fatalf("tell action missing semantic metadata: %+v", action)
		}
		if action.Kind == "tell" && len(action.Warnings) == 0 {
			t.Fatalf("unverified tell action missing warning: %+v", action)
		}
		if action.Kind == "tell" && (action.TargetRole == "" || action.Relevance == "" || action.Risk == "") {
			t.Fatalf("tell action missing public decision context: %+v", action)
		}
		if action.ID == "wait:next" && !containsMessage(action.Warnings, "解瘴丹") {
			t.Fatalf("advance action missing expiring-opportunity warning: %+v", action)
		}
	}
	verify := actionWithID(view.AvailableActions, "verify:F02")
	if verify == nil || verify.CompletionDay != 2 || !containsMessage(verify.Resolves, "尚未核实") || !strings.Contains(verify.Timing, "传闻口径") || !strings.Contains(verify.Timing, "预留 19 日") {
		t.Fatalf("initial verification summary = %+v", verify)
	}
	antidote := actionWithID(view.AvailableActions, "buy:M01:antidote")
	if antidote == nil || !containsMessage(antidote.Resolves, "缺少解瘴丹") || !containsMessage(antidote.ExpectedOutcomes, "核心目标") {
		t.Fatalf("antidote purchase summary = %+v", antidote)
	}
	if strings.Contains(string(encoded), "按已核实日期") || strings.Contains(string(encoded), "青髓芝将在第21天成熟") {
		t.Fatalf("initial action summaries leaked verified timing: %s", encoded)
	}
}

func TestActionTimingUpdatesAfterPlayerVerifiesDate(t *testing.T) {
	session := testSession(t)
	executeMany(t, session, []string{"verify:F02", "wait:complete"})
	view := session.View()
	action := actionWithID(view.AvailableActions, "buy:M01:antidote")
	if action == nil || action.CompletionDay != 3 || !strings.Contains(action.Timing, "已核实") || strings.Contains(action.Timing, "传闻") || !strings.Contains(action.Timing, "预留 15 日") {
		t.Fatalf("verified action timing = %+v", action)
	}
}

func TestVerifiedClueExplainsWhyTargetMayCare(t *testing.T) {
	session := testSession(t)
	executeMany(t, session, []string{"verify:F02", "wait:complete", "move:L02"})
	view := session.View()
	foundTerms := make(map[string]bool)
	for _, action := range view.AvailableActions {
		if !strings.HasPrefix(action.ID, "tell:N03:F01:") {
			continue
		}
		if action.TargetRole != "青岚门行动负责人" || !strings.Contains(action.Relevance, "成熟时机") {
			t.Fatalf("Shen relevance = %+v", action)
		}
		if !strings.Contains(action.Risk, "整支队伍") {
			t.Fatalf("Shen public risk = %q", action.Risk)
		}
		if action.TermLabel == "" || action.PersonalOutcome == "" {
			t.Fatalf("Shen term lacks personal stakes = %+v", action)
		}
		foundTerms[action.TermID] = true
	}
	for _, termID := range []string{"trust", "antidote", "escort"} {
		if !foundTerms[termID] {
			t.Fatalf("verified clue missing Shen term %s: %+v", termID, foundTerms)
		}
	}
}

func TestShenDateTermsProduceDistinctPersonalAndRelationshipEffects(t *testing.T) {
	tests := []struct {
		term         string
		wantTrust    int
		wantAntidote int
		wantFlag     string
		wantState    string
	}{
		{term: "trust", wantTrust: 2, wantFlag: "qinglan_intel_term_trust", wantState: "trust_committed"},
		{term: "antidote", wantAntidote: 1, wantFlag: "qinglan_intel_term_antidote", wantState: "antidote_committed"},
		{term: "escort", wantTrust: 1, wantFlag: "qinglan_escort_promised", wantState: "escort_committed"},
	}
	for _, test := range tests {
		t.Run(test.term, func(t *testing.T) {
			session := testSession(t)
			executeMany(t, session, []string{"verify:F02", "wait:complete", "move:L02", "tell:N03:F01:" + test.term})
			state := session.engine.State()
			if got := state.RelationBetween("N03", state.Player.ID).Trust; got != test.wantTrust {
				t.Fatalf("trust = %d, want %d", got, test.wantTrust)
			}
			if got := state.Player.Items["antidote"]; got != test.wantAntidote {
				t.Fatalf("antidote = %d, want %d", got, test.wantAntidote)
			}
			if test.term == "antidote" && state.NPCs["N03"].Items["antidote"] != 0 {
				t.Fatalf("the traded antidote was not removed from Shen: %+v", state.NPCs["N03"].Items)
			}
			if !state.ActorFlag(state.Player.ID, test.wantFlag) {
				t.Fatalf("term flag %s was not recorded", test.wantFlag)
			}
			if got := state.StoryStates["qinglan_intel"]; got != test.wantState {
				t.Fatalf("story state = %s, want %s", got, test.wantState)
			}
			progress := routeProgressWithID(session.View().RouteProgresses, test.term)
			if progress == nil || progress.ID != test.term || progress.NextStep == "" || progress.PersonalReturn == "" {
				t.Fatalf("route %s has no persistent progress summary: %+v", test.term, progress)
			}
		})
	}
}

func TestStoryConsequencesProjectStateAndRuntimeValues(t *testing.T) {
	session := testSession(t)
	state := &domain.WorldState{
		Player:      &domain.PlayerState{ID: "P00"},
		StoryStates: map[string]string{"qinglan_intel": "trust_betrayed"},
		ActorFlags:  map[string]map[string]bool{"P00": {}},
		WorldFlags:  map[string]bool{},
		Relations: map[string]domain.Relation{
			domain.RelationKey("N03", "P00"): {From: "N03", To: "P00", Trust: -2},
		},
	}
	consequences := session.storyConsequences(state)
	if len(consequences) != 1 || !strings.Contains(consequences[0], "最终信任为 -2") {
		t.Fatalf("trust consequence = %v", consequences)
	}

	state.StoryStates["qinglan_intel"] = "antidote_scouted"
	consequences = session.storyConsequences(state)
	if len(consequences) != 2 || !containsMessage(consequences, "拒绝归还") || !containsMessage(consequences, "提前踩点") {
		t.Fatalf("antidote consequences = %v", consequences)
	}

	state.StoryStates["qinglan_intel"] = "escort_vanguard"
	state.WorldFlags["chen_treats_player_as_qinglan"] = true
	consequences = session.storyConsequences(state)
	if len(consequences) != 3 || !containsMessage(consequences, "兑现同行承诺") || !containsMessage(consequences, "先锋分工") || !containsMessage(consequences, "视你为青岚门行动的一员") {
		t.Fatalf("escort consequences = %v", consequences)
	}
	state.WorldFlags["player_declared_independent"] = true
	if consequences = session.storyConsequences(state); len(consequences) != 2 || containsMessage(consequences, "视你为青岚门行动的一员") {
		t.Fatalf("independent escort consequences = %v", consequences)
	}
}

func TestShenTrustChangesHisImmediateStrategy(t *testing.T) {
	session := testSession(t)
	executeMany(t, session, []string{"verify:F02", "wait:complete", "move:L02", "tell:N03:F01:trust", "wait:next"})
	state := session.engine.State()
	if !state.NPCs["N03"].Completed["N03-early-prepare"] || state.NPCs["N03"].Completed["N03-check-player-source"] {
		t.Fatalf("trusted source did not cause immediate preparation: completed=%+v", state.NPCs["N03"].Completed)
	}
	foundRelationshipChange := false
	for _, decision := range state.Decisions {
		if decision.ActorID == "N03" && decision.Day == 5 && decision.RelationshipChangedTop && decision.WithoutRelationshipStrategyID == "N03-check-player-source" {
			foundRelationshipChange = true
			break
		}
	}
	if !foundRelationshipChange {
		t.Fatalf("day 5 decision did not record relationship as top-choice cause: %+v", state.Decisions)
	}
}

func TestEscortPromiseReturnsAsLateGameRouteChoice(t *testing.T) {
	session := testSession(t)
	executeMany(t, session, []string{"verify:F02", "wait:complete", "move:L02", "tell:N03:F01:escort"})
	view := session.View()
	for view.Day < 16 {
		var err error
		view, err = session.Execute("wait:next")
		if err != nil {
			t.Fatal(err)
		}
		if actionWithID(view.AvailableActions, "route:escort:review") != nil {
			if !session.engine.State().WorldFlag("chen_treats_player_as_qinglan") {
				t.Fatal("Chen Qingshan did not react to the player's Qinglan affiliation")
			}
			view, err = session.Execute("route:escort:review")
			if err != nil {
				t.Fatal(err)
			}
		}
	}
	if view.Day != 16 || actionWithID(view.AvailableActions, "escort:N03:depart") == nil {
		t.Fatalf("escort promise did not return on opening day: day=%d actions=%v", view.Day, actionIDs(view.AvailableActions))
	}
	view, err := session.Execute("escort:N03:depart")
	if err != nil {
		t.Fatal(err)
	}
	if view.Location.ID != "L02" || itemAmount(view.Player.Items, "antidote") != 1 || view.Player.Resources["support"] != 1 || actionWithID(view.AvailableActions, "move:L04") == nil {
		t.Fatalf("escort fulfillment = player %+v at %+v", view.Player, view.Location)
	}
	state := session.engine.State()
	if !state.ActorFlag(state.Player.ID, "qinglan_escort_fulfilled") {
		t.Fatal("escort fulfillment was not recorded")
	}
	if actionWithID(view.AvailableActions, "route:escort:vanguard") == nil || actionWithID(view.AvailableActions, "route:escort:quartermaster") == nil {
		t.Fatalf("escort fulfillment did not create a personal role choice: %v", actionIDs(view.AvailableActions))
	}
	view, err = session.Execute("route:escort:vanguard")
	if err != nil {
		t.Fatal(err)
	}
	if view.Preparation.TotalScore != 7 || view.Preparation.Rating != "优势明显" || view.Player.Resources["support"] != 4 {
		t.Fatalf("vanguard role did not create a competitive route: player=%+v preparation=%+v", view.Player, view.Preparation)
	}
	executeMany(t, session, []string{"move:L04", "move:L05", "wait:next"})
	view = session.View()
	if !view.Resolved || !strings.Contains(view.Outcome, view.Player.Name) {
		t.Fatalf("fulfilled vanguard route did not support a player victory: %q", view.Outcome)
	}
}

func TestAntidoteRouteForcesKeepOrLendDecision(t *testing.T) {
	session := testSession(t)
	executeMany(t, session, []string{"verify:F02", "wait:complete", "move:L02", "tell:N03:F01:antidote"})
	view := session.View()
	for actionWithID(view.AvailableActions, "route:antidote:lend") == nil && view.Day < 12 {
		var err error
		view, err = session.Execute("wait:next")
		if err != nil {
			t.Fatal(err)
		}
	}
	if view.Day != 8 || actionWithID(view.AvailableActions, "route:antidote:lend") == nil || actionWithID(view.AvailableActions, "route:antidote:keep") == nil {
		t.Fatalf("Su Wanzhao request did not create a route decision: day=%d actions=%v", view.Day, actionIDs(view.AvailableActions))
	}
	view, err := session.Execute("route:antidote:lend")
	if err != nil {
		t.Fatal(err)
	}
	state := session.engine.State()
	if itemAmount(view.Player.Items, "antidote") != 0 || view.Player.Resources["support"] != 2 || state.NPCs["N06"].Items["antidote"] != 1 || state.RelationBetween("N06", state.Player.ID).Trust != 2 {
		t.Fatalf("lend route result = player=%+v su_items=%+v relation=%+v", view.Player, state.NPCs["N06"].Items, state.RelationBetween("N06", state.Player.ID))
	}
}

func TestRouteMidgameAlternativesCarryTheirCosts(t *testing.T) {
	t.Run("betray trust", func(t *testing.T) {
		session := testSession(t)
		executeMany(t, session, []string{"verify:F02", "wait:complete", "move:L02", "tell:N03:F01:trust"})
		advanceToAction(t, session, "route:trust:leak", 12)
		view, err := session.Execute("route:trust:leak")
		if err != nil {
			t.Fatal(err)
		}
		state := session.engine.State()
		if view.Player.Resources["spirit_stones"] != 120 || state.RelationBetween("N03", state.Player.ID).Trust != -2 || state.NPCs["N09"].Beliefs["F01"].Confidence != 3 {
			t.Fatalf("betrayal result = player=%+v relation=%+v belief=%+v", view.Player, state.RelationBetween("N03", state.Player.ID), state.NPCs["N09"].Beliefs["F01"])
		}
		if !containsMessage(session.playerConsequences(state), "20 灵石") {
			t.Fatalf("betrayal consequence is not explained: %v", session.playerConsequences(state))
		}
	})

	t.Run("keep antidote", func(t *testing.T) {
		session := testSession(t)
		executeMany(t, session, []string{"verify:F02", "wait:complete", "move:L02", "tell:N03:F01:antidote"})
		advanceToAction(t, session, "route:antidote:keep", 12)
		view, err := session.Execute("route:antidote:keep")
		if err != nil {
			t.Fatal(err)
		}
		state := session.engine.State()
		if itemAmount(view.Player.Items, "antidote") != 1 || state.RelationBetween("N06", state.Player.ID).Suspicion != 2 {
			t.Fatalf("keep result = player=%+v relation=%+v", view.Player, state.RelationBetween("N06", state.Player.ID))
		}
		if !containsMessage(session.playerConsequences(state), "保留独自决定") {
			t.Fatalf("independent antidote consequence is not explained: %v", session.playerConsequences(state))
		}
		view = advanceToAction(t, session, "route:antidote:scout", 16)
		if actionWithID(view.AvailableActions, "route:antidote:liquidate") == nil {
			t.Fatalf("kept antidote has no profit alternative: %v", actionIDs(view.AvailableActions))
		}
		view, err = session.Execute("route:antidote:scout")
		if err != nil {
			t.Fatal(err)
		}
		progress := routeProgressWithID(view.RouteProgresses, "antidote")
		if view.Player.Resources["support"] != 2 || view.Preparation.TotalScore != 5 || progress == nil || !progress.Complete {
			t.Fatalf("antidote scouting did not create usable preparation: player=%+v preparation=%+v routes=%+v", view.Player, view.Preparation, view.RouteProgresses)
		}
	})

	t.Run("leave escort", func(t *testing.T) {
		session := testSession(t)
		executeMany(t, session, []string{"verify:F02", "wait:complete", "move:L02", "tell:N03:F01:escort"})
		advanceToAction(t, session, "route:escort:independent", 13)
		if _, err := session.Execute("route:escort:independent"); err != nil {
			t.Fatal(err)
		}
		state := session.engine.State()
		if state.ActorFlag(state.Player.ID, "qinglan_escort_promised") || !state.ActorFlag(state.Player.ID, "qinglan_escort_refused") || state.RelationBetween("N02", state.Player.ID).Suspicion != 0 {
			t.Fatalf("independent result = flags=%+v relation=%+v", state.ActorFlags[state.Player.ID], state.RelationBetween("N02", state.Player.ID))
		}
		if !containsMessage(session.playerConsequences(state), "退出同行名单") {
			t.Fatalf("escort exit consequence is not explained: %v", session.playerConsequences(state))
		}
	})
}

func advanceToAction(t *testing.T, session *Session, actionID string, maxDay int) PlayerView {
	t.Helper()
	view := session.View()
	for actionWithID(view.AvailableActions, actionID) == nil && view.Day < maxDay {
		var err error
		view, err = session.Execute("wait:next")
		if err != nil {
			t.Fatal(err)
		}
	}
	if actionWithID(view.AvailableActions, actionID) == nil {
		t.Fatalf("action %s did not appear by day %d: %v", actionID, view.Day, actionIDs(view.AvailableActions))
	}
	return view
}

func actionWithID(actions []AvailableAction, id string) *AvailableAction {
	for index := range actions {
		if actions[index].ID == id {
			return &actions[index]
		}
	}
	return nil
}

func routeProgressWithID(progresses []RouteProgress, id string) *RouteProgress {
	for index := range progresses {
		if progresses[index].ID == id {
			return &progresses[index]
		}
	}
	return nil
}

func mapRoute(routes []VisibleMapRoute, fromID, toID string) *VisibleMapRoute {
	for index := range routes {
		if routes[index].FromID == fromID && routes[index].ToID == toID {
			return &routes[index]
		}
	}
	return nil
}

func TestAtomicSaveFileCanReplaceAndReload(t *testing.T) {
	session := testSession(t)
	path := filepath.Join(t.TempDir(), "slot.json")
	if err := session.SaveFile(path); err != nil {
		t.Fatal(err)
	}
	if _, err := session.Execute("wait:next"); err != nil {
		t.Fatal(err)
	}
	if err := session.SaveFile(path); err != nil {
		t.Fatal(err)
	}
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	restored, err := LoadFile(bundle, path)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(session.View(), restored.View()) {
		t.Fatalf("atomic save reload differs")
	}
	matches, err := filepath.Glob(filepath.Join(filepath.Dir(path), ".narra-save-*.tmp"))
	if err != nil || len(matches) != 0 {
		t.Fatalf("temporary saves left behind: %v, %v", matches, err)
	}
}

func TestSaveBindsReplayToContentHash(t *testing.T) {
	session := testSession(t)
	var encoded bytes.Buffer
	if err := session.Save(&encoded); err != nil {
		t.Fatal(err)
	}
	var saved SaveData
	if err := json.Unmarshal(encoded.Bytes(), &saved); err != nil {
		t.Fatal(err)
	}
	if saved.Version != currentSaveVersion || saved.ContentVersion != session.bundle.Content.Version || saved.ContentHash != session.bundle.Content.Hash {
		t.Fatalf("save metadata = %+v, bundle = %+v", saved, session.bundle.Content)
	}

	changed := session.bundle
	changed.Content.Hash = "sha256:changed"
	if _, err := LoadSession(changed, bytes.NewReader(encoded.Bytes())); err == nil || !strings.Contains(err.Error(), "does not match loaded content") {
		t.Fatalf("content mismatch error = %v", err)
	}
}

func TestLoadSessionRejectsNonCurrentSaveVersions(t *testing.T) {
	session := testSession(t)
	for _, version := range []int{1, 2, currentSaveVersion + 1} {
		encoded, err := json.Marshal(SaveData{
			Version: version, ScenarioID: session.bundle.Scenario.ID, Player: clonePlayerConfig(session.initial),
		})
		if err != nil {
			t.Fatal(err)
		}
		if _, err := LoadSession(session.bundle, bytes.NewReader(encoded)); err == nil || !strings.Contains(err.Error(), "unsupported save version") {
			t.Fatalf("save version %d error = %v", version, err)
		}
	}
}

func TestBuyAndInvestigationUseAuthoritativeEngine(t *testing.T) {
	session := testSession(t)
	if got := session.engine.State().Markets["M01"].Currency; got != "spirit_stones" {
		t.Fatalf("market currency = %q", got)
	}
	buyOption := session.actionOptions(session.engine.State())["buy:M01:antidote"]
	if buyOption.command == nil || buyOption.command.Costs["spirit_stones"] != 20 || len(buyOption.command.Effects) != 1 {
		t.Fatalf("buy option = %+v", buyOption)
	}
	view, err := session.Execute("buy:M01:antidote")
	if err != nil {
		t.Fatal(err)
	}
	if view.Day != 1 || view.Player.Resources["spirit_stones"] != 80 || itemAmount(view.Player.Items, "antidote") != 1 {
		t.Fatalf("view after purchase = %+v", view.Player)
	}
	if view.LastTurn == nil || view.LastTurn.Status != "completed" || !containsMessage(view.LastTurn.Messages, "灵石 -20") || !containsMessage(view.LastTurn.Messages, "解瘴丹 +1") {
		t.Fatalf("purchase feedback = %+v", view.LastTurn)
	}
	if view.LastTurn.Presentation == nil || view.LastTurn.Presentation.Kind != "acquire" {
		t.Fatalf("purchase presentation cue = %+v", view.LastTurn.Presentation)
	}

	view, err = session.Execute("verify:F02")
	if err != nil {
		t.Fatal(err)
	}
	if !view.Player.Busy || len(view.AvailableActions) != 1 || view.AvailableActions[0].ID != "wait:complete" {
		t.Fatalf("multi-day action state = %+v / %+v", view.Player, view.AvailableActions)
	}
	if view.LastTurn == nil || view.LastTurn.Status != "started" {
		t.Fatalf("investigation start feedback = %+v", view.LastTurn)
	}
	view, err = session.Execute("wait")
	if err != nil {
		t.Fatal(err)
	}
	if view.Day != 3 || view.Player.Busy || beliefConfidence(view.KnownFacts, "F02") != 3 {
		t.Fatalf("completed investigation view = %+v", view)
	}
	if view.LastTurn == nil || !containsMessage(view.LastTurn.Messages, "线索更新") {
		t.Fatalf("investigation completion feedback = %+v", view.LastTurn)
	}
	if view.LastTurn.Presentation == nil || view.LastTurn.Presentation.Kind != "reveal" || view.LastTurn.Presentation.SubjectID != "F01" {
		t.Fatalf("investigation presentation cue = %+v", view.LastTurn.Presentation)
	}
}

func TestInitialGuidanceExplainsCoreDecisionWithoutLeakingTrueDate(t *testing.T) {
	view := testSession(t).View()
	joined := strings.Join(view.Guidance, " ")
	for _, want := range []string{"只是传闻", "解瘴丹"} {
		if !strings.Contains(joined, want) {
			t.Errorf("guidance %q does not mention %q", joined, want)
		}
	}
	if strings.Contains(joined, "第21天") {
		t.Fatalf("guidance leaked the true maturity date: %s", joined)
	}
	if view.Travel == nil || view.Travel.TravelDays != 3 || view.Travel.Ready || !containsMessage(view.Travel.Blockers, "缺少解瘴丹") || !containsMessage(view.Travel.Blockers, "入口尚未开放") || !strings.Contains(view.Travel.Timing, "未经核实") {
		t.Fatalf("initial travel guidance = %+v", view.Travel)
	}
	if len(view.Travel.Route) < 2 || !containsMessage(view.Travel.Route, "黑风谷") || !travelCheckReady(view.Travel.Checks, "可用路线", true) || !travelCheckReady(view.Travel.Checks, "携带解瘴丹", false) || !travelCheckReady(view.Travel.Checks, "入口开放", false) {
		t.Fatalf("initial travel route/checks = %+v", view.Travel)
	}
	if !preparationFactorReady(view.Preparation.ScoreSources, "combat", true) || !preparationFactorReady(view.Preparation.ScoreSources, "support", false) || !preparationFactorReady(view.Preparation.Conditions, "required_item", false) || !preparationFactorReady(view.Preparation.Conditions, "location", false) || view.Preparation.TotalScore != 2 || view.Preparation.TargetScore != 6 || view.Preparation.Rating != "明显不足" || view.Preparation.Eligible {
		t.Fatalf("initial preparation summary = %+v", view.Preparation)
	}
}

func TestWaitUntilCompleteSkipsBusyDays(t *testing.T) {
	session := testSession(t)
	if _, err := session.Execute("cultivate"); err != nil {
		t.Fatal(err)
	}
	view, err := session.Execute("wait:complete")
	if err != nil {
		t.Fatal(err)
	}
	if view.Day != 3 || view.Player.Busy || view.LastTurn == nil || view.LastTurn.DaysAdvanced != 2 {
		t.Fatalf("wait until complete view = %+v", view)
	}
	if view.Metrics.DecisionInputs != 2 || view.Metrics.AutoAdvancedDays != 2 {
		t.Fatalf("wait until complete metrics = %+v", view.Metrics)
	}
}

func TestRepeatedCultivationBecomesAnExplicitHighCostAlternative(t *testing.T) {
	session := testSession(t)
	executeMany(t, session, []string{"cultivate", "wait:complete", "cultivate", "wait:complete"})
	third := actionWithID(session.View().AvailableActions, "cultivate")
	if third == nil || third.Costs["spirit_stones"] != 10 || !containsMessage(third.Warnings, "高耗阶段") || !strings.Contains(third.Description, "第 3 阶段") || !strings.Contains(third.Description, "累计闭关耗费 10 灵石") {
		t.Fatalf("third cultivation does not expose escalating cost: %+v", third)
	}
	view, err := session.Execute("cultivate")
	if err != nil {
		t.Fatal(err)
	}
	if view.Player.Resources["spirit_stones"] != 90 || view.LastTurn == nil || !containsMessage(view.LastTurn.Messages, "灵石 -10") {
		t.Fatalf("third cultivation did not charge its visible cost: %+v / %+v", view.Player, view.LastTurn)
	}
	executeMany(t, session, []string{"wait:complete"})
	fourth := actionWithID(session.View().AvailableActions, "cultivate")
	if fourth == nil || fourth.Costs["spirit_stones"] != 20 {
		t.Fatalf("fourth cultivation cost = %+v", fourth)
	}
}

func TestMissedMarketCanRecoverPersonalRouteThroughInformationTrade(t *testing.T) {
	session := testSession(t)
	executeMany(t, session, []string{"verify:F02", "wait:complete", "move:L02", "wait", "wait", "wait", "wait", "wait"})
	view := session.View()
	recovery := actionWithID(view.AvailableActions, "recover:N06:antidote")
	if view.Day != 8 || recovery == nil || !recovery.Irreversible || !containsMessage(recovery.Resolves, "坊市封锁") || len(recovery.Unknowns) == 0 {
		t.Fatalf("day 8 recovery action = %+v at day %d", recovery, view.Day)
	}
	if !containsMessage(view.Guidance, "核实") || !containsMessage(view.Guidance, "解瘴丹") {
		t.Fatalf("recovery guidance = %v", view.Guidance)
	}
	view, err := session.Execute(recovery.ID)
	if err != nil {
		t.Fatal(err)
	}
	if itemAmount(view.Player.Items, "antidote") != 1 || view.Travel == nil || containsMessage(view.Travel.Blockers, "缺少解瘴丹") {
		t.Fatalf("recovery did not reopen travel: player=%+v travel=%+v", view.Player, view.Travel)
	}
	if !hasCausalStage(view.CausalThreads, "苏晚照", "F01", "delivered") {
		t.Fatalf("recovery information trade is not traceable: %+v", view.CausalThreads)
	}
	if !preparationFactorReady(view.Preparation.Conditions, "required_item", true) {
		t.Fatalf("recovered antidote did not update preparation summary: %+v", view.Preparation)
	}
	if got := session.engine.State().StoryStates["antidote_recovery"]; got != "recovered" {
		t.Fatalf("recovery story state = %q", got)
	}
	if view.LastTurn == nil || !containsMessage(view.LastTurn.Messages, "苏晚照接受了核实日期") || !containsMessage(view.LastTurn.Journal, "亲自入谷路线重新开放") || view.LastTurn.Presentation == nil || view.LastTurn.Presentation.Kind != "recovery" {
		t.Fatalf("content-backed recovery feedback = %+v", view.LastTurn)
	}
}

func TestTravelGuidanceSeparatesItemRouteAndKnownDeadline(t *testing.T) {
	session := testSession(t)
	executeMany(t, session, []string{"buy:M01:antidote", "verify:F02", "wait:complete"})
	view := session.View()
	if view.Travel == nil || containsMessage(view.Travel.Blockers, "缺少解瘴丹") || !containsMessage(view.Travel.Blockers, "入口尚未开放") || !strings.Contains(view.Travel.Timing, "已核实日期") {
		t.Fatalf("prepared travel guidance = %+v", view.Travel)
	}
	if !travelCheckReady(view.Travel.Checks, "携带解瘴丹", true) || !travelCheckReady(view.Travel.Checks, "入口开放", false) {
		t.Fatalf("prepared travel checks = %+v", view.Travel.Checks)
	}
	for view.Day < 17 {
		view, _ = session.Execute("wait")
	}
	if view.Travel == nil || !view.Travel.Ready || len(view.Travel.Blockers) != 0 {
		t.Fatalf("day 17 travel guidance = %+v", view.Travel)
	}
	if !travelCheckReady(view.Travel.Checks, "携带解瘴丹", true) || !travelCheckReady(view.Travel.Checks, "入口开放", true) {
		t.Fatalf("ready travel checks = %+v", view.Travel.Checks)
	}
}

func TestWorldDirectorOpportunityBecomesAuthoritativePlayerAction(t *testing.T) {
	session := testSession(t)
	for day := 0; day < 3; day++ {
		if _, err := session.Execute("wait"); err != nil {
			t.Fatal(err)
		}
	}
	view := session.View()
	action := actionWithID(view.AvailableActions, "opportunity:wandering_broker")
	if action.ID == "" || action.Kind != "opportunity" || action.Category != "investigate" {
		t.Fatalf("director opportunity action = %+v", action)
	}
	view, err := session.Execute(action.ID)
	if err != nil {
		t.Fatal(err)
	}
	if actionWithID(view.AvailableActions, action.ID) != nil {
		t.Fatalf("consumed opportunity remained available: %+v", view.AvailableActions)
	}
	found := false
	for _, belief := range view.KnownFacts {
		if belief.FactID == "F09" && belief.Confidence == 2 {
			if belief.Source != "路过游商" {
				t.Fatalf("opportunity source was not localized: %+v", belief)
			}
			found = true
		}
	}
	if !found || view.Day != 4 {
		t.Fatalf("opportunity did not produce its authoritative result: %+v", view)
	}
}

func TestInvalidActionDoesNotAdvanceSession(t *testing.T) {
	session := testSession(t)
	if _, err := session.Execute("not-an-action"); err == nil {
		t.Fatal("invalid action unexpectedly succeeded")
	}
	if session.View().Day != 0 || len(session.History()) != 0 {
		t.Fatalf("invalid action changed session: day=%d history=%v", session.View().Day, session.History())
	}
}

func TestSaveLoadsByDeterministicReplay(t *testing.T) {
	session := testSession(t)
	for _, action := range []string{"buy:M01:antidote", "move:L02", "wait"} {
		if _, err := session.Execute(action); err != nil {
			t.Fatalf("execute %s: %v", action, err)
		}
	}
	var data bytes.Buffer
	if err := session.Save(&data); err != nil {
		t.Fatal(err)
	}
	if strings.Contains(data.String(), "world_flags") || strings.Contains(data.String(), "npcs") {
		t.Fatalf("save serialized engine internals: %s", data.String())
	}

	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	restored, err := LoadSession(bundle, &data)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(session.View(), restored.View()) || !reflect.DeepEqual(session.History(), restored.History()) {
		t.Fatalf("restored session differs\nwant: %+v\ngot:  %+v", session.View(), restored.View())
	}
}

func TestSaveReplayPreservesPostResolutionHistory(t *testing.T) {
	session := testSession(t)
	executeUntilResolved(t, session)
	for session.engine.State().Day < 30 {
		if _, err := session.execute("wait", true); err != nil {
			t.Fatal(err)
		}
	}
	var data bytes.Buffer
	if err := session.Save(&data); err != nil {
		t.Fatal(err)
	}
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	restored, err := LoadSession(bundle, &data)
	if err != nil {
		t.Fatal(err)
	}
	if restored.engine.State().Day != 30 || restored.metrics.PostResultInputs != 9 {
		t.Fatalf("restored post-resolution history day/metrics = %d/%+v", restored.engine.State().Day, restored.metrics)
	}
}

func TestSaveReplayPreservesMacroAdvance(t *testing.T) {
	session := testSession(t)
	if _, err := session.Execute("wait:next"); err != nil {
		t.Fatal(err)
	}
	var data bytes.Buffer
	if err := session.Save(&data); err != nil {
		t.Fatal(err)
	}
	bundle, err := scenario.Load("../../data/blackwind")
	if err != nil {
		t.Fatal(err)
	}
	restored, err := LoadSession(bundle, &data)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(session.View(), restored.View()) {
		t.Fatalf("macro replay differs\nwant: %+v\ngot:  %+v", session.View(), restored.View())
	}
}

func TestDemoObserverJourneyReachesExplainedEnding(t *testing.T) {
	session := testSession(t)
	executeUntilResolved(t, session)
	view := session.View()
	if !view.Resolved || view.Ended || view.Day != 21 || view.Ending == nil || !strings.Contains(view.Outcome, "李玄") {
		t.Fatalf("observer ending = %+v", view.Ending)
	}
	if view.AvailableActions == nil || len(view.AvailableActions) != 0 || strings.Contains(view.Outcome, "准备值") {
		t.Fatalf("ending protocol/action state = %#v / %q", view.AvailableActions, view.Outcome)
	}
	if !containsMessage(view.Ending.Highlights, "21 次决策") || !containsMessage(view.Ending.Highlights, "推进时间 21 次") {
		t.Fatalf("observer highlights = %v", view.Ending.Highlights)
	}
	if !containsMessage(view.Ending.Review, "没有解瘴丹") || !containsMessage(view.Ending.Review, "没有进行主动行动") || !containsMessage(view.Ending.Review, "下一局") {
		t.Fatalf("observer ending has no actionable loss review: %v", view.Ending.Review)
	}
	if view.Metrics.CoreResultDay != 21 || view.Metrics.PostResultInputs != 0 || view.Metrics.DecisionInputs != 21 {
		t.Fatalf("observer metrics = %+v", view.Metrics)
	}
	if _, err := session.Execute("wait"); err == nil {
		t.Fatal("public session accepted input after core resolution")
	}
}

func TestDemoObserverCanAdvanceOnlyAtDecisionPoints(t *testing.T) {
	session := testSession(t)
	var stops []int
	for !session.View().Resolved {
		view, err := session.Execute("wait:next")
		if err != nil {
			t.Fatal(err)
		}
		stops = append(stops, view.Day)
	}
	if len(stops) > 4 || stops[len(stops)-1] != 21 {
		t.Fatalf("observer advance stops = %v", stops)
	}
	view := session.View()
	if view.Metrics.DecisionInputs > 4 || view.Metrics.AutoAdvancedDays != 21 {
		t.Fatalf("observer macro metrics = %+v", view.Metrics)
	}
}

func TestDemoInvestigatorJourneyChangesPlayerKnowledge(t *testing.T) {
	session := testSession(t)
	executeMany(t, session, []string{"verify:F02", "wait"})
	executeUntilResolved(t, session)
	view := session.View()
	if !view.Resolved || beliefConfidence(view.KnownFacts, "F02") != 3 || beliefConfidence(view.KnownFacts, "F01") != 3 || beliefConfidence(view.KnownFacts, "F08") != 2 {
		t.Fatalf("investigator journey did not preserve verified knowledge: %+v", view.KnownFacts)
	}
	if view.Ending == nil || !containsMessage(view.Ending.Highlights, "核验情报 1 次") {
		t.Fatalf("investigator highlights = %+v", view.Ending)
	}
	for _, fact := range view.KnownFacts {
		if strings.HasPrefix(fact.Source, "player-") {
			t.Fatalf("player-facing source leaked internal code: %+v", fact)
		}
	}
}

func TestDemoPreparedContenderCanWinCoreContest(t *testing.T) {
	session := testSession(t)
	actions := []string{
		"buy:M01:antidote",
		"cultivate", "wait", "wait",
		"cultivate", "wait", "wait",
		"cultivate", "wait", "wait",
		"cultivate", "wait", "wait",
		"cultivate", "wait", "wait",
		"wait",
		"move:L04", "wait",
		"move:L05",
	}
	actions = append(actions, "wait")
	executeMany(t, session, actions)
	view := session.View()
	if !view.Resolved || view.Day != 21 || !strings.Contains(view.Outcome, "测试玩家") {
		t.Fatalf("prepared contender outcome = %q", view.Outcome)
	}
	if view.Player.Resources["combat"] != 7 || view.Player.Resources["spirit_stones"] != 20 || view.Location.ID != "L05" {
		t.Fatalf("prepared contender state = %+v at %+v", view.Player, view.Location)
	}
}

func TestDemoMessengerJourneyRecordsDeliveredInfluence(t *testing.T) {
	session := testSession(t)
	actions := []string{"verify:F02", "wait:complete", "move:L02", "tell:N03:F01:trust"}
	for index, action := range actions {
		view, err := session.Execute(action)
		if err != nil {
			t.Fatalf("turn %d execute %s: %v", index+1, action, err)
		}
		if action == "tell:N03:F01:trust" && (view.LastTurn == nil || !containsMessage(view.LastTurn.Messages, "情报已经送达沈砚秋")) {
			t.Fatalf("message delivery feedback = %+v", view.LastTurn)
		}
		if action == "tell:N03:F01:trust" && actionIDs(view.AvailableActions)[action] {
			t.Fatalf("delivered fact remained available: %s", action)
		}
		if action == "tell:N03:F01:trust" {
			if !hasCausalStage(view.CausalThreads, "沈砚秋", "F01", "delivered") {
				t.Fatalf("delivery has no persistent causal thread: %+v", view.CausalThreads)
			}
			for _, event := range view.RecentEvents {
				if strings.Contains(event.Description, "F01") {
					t.Fatalf("visible event leaked internal fact ID: %q", event.Description)
				}
			}
		}
	}
	view, err := session.Execute("wait:next")
	if err != nil {
		t.Fatal(err)
	}
	if view.LastTurn == nil || !hasDecisionChange(view.LastTurn.Influence, "沈砚秋", "F01", 5) {
		t.Fatalf("day 5 immediate influence = %+v", view.LastTurn)
	}
	if !hasCausalStage(view.CausalThreads, "沈砚秋", "F01", "changed") {
		t.Fatalf("causal thread did not advance to changed: %+v", view.CausalThreads)
	}
	if !strings.Contains(view.LastTurn.StopReason, "消息改变") {
		t.Fatalf("day 5 advance does not explain why it stopped: %+v", view.LastTurn)
	}
	if !containsMessage(view.Guidance, "市场") || !containsMessage(view.Guidance, "解瘴丹") {
		t.Fatalf("day 5 guidance did not preserve the personal route choice: %v", view.Guidance)
	}
	for _, wantDay := range []int{8, 10} {
		view, err = session.Execute("wait:next")
		if err != nil {
			t.Fatal(err)
		}
		if view.Day != wantDay {
			t.Fatalf("advance stopped on day %d, want %d", view.Day, wantDay)
		}
		if wantDay == 8 && actionWithID(view.AvailableActions, "recover:N06:antidote") == nil {
			t.Fatalf("day 8 did not surface the missed-market recovery choice: %+v", view.AvailableActions)
		}
		if wantDay == 8 && !strings.Contains(view.LastTurn.StopReason, "以情报换取解瘴丹") {
			t.Fatalf("day 8 stop reason = %+v", view.LastTurn)
		}
		if wantDay == 10 && (actionWithID(view.AvailableActions, "route:trust:vouch") == nil || actionWithID(view.AvailableActions, "route:trust:leak") == nil) {
			t.Fatalf("day 10 did not surface the trust-route test: %+v", view.AvailableActions)
		}
	}
	view, err = session.Execute("route:trust:vouch")
	if err != nil {
		t.Fatal(err)
	}
	if view.Player.Resources["credit"] != 4 || session.engine.State().RelationBetween("N03", view.Player.ID).Trust != 3 {
		t.Fatalf("public vouch did not change credit and trust: player=%+v relation=%+v", view.Player, session.engine.State().RelationBetween("N03", view.Player.ID))
	}
	view, err = session.Execute("wait:next")
	if err != nil {
		t.Fatal(err)
	}
	if view.Day != 14 || actionWithID(view.AvailableActions, "route:trust:join") == nil || actionWithID(view.AvailableActions, "route:trust:commission") == nil {
		t.Fatalf("day 14 did not surface the trust payoff choice: day=%d actions=%v", view.Day, actionIDs(view.AvailableActions))
	}
	view, err = session.Execute("route:trust:join")
	if err != nil {
		t.Fatal(err)
	}
	if !preparationFactorReady(view.Preparation.Conditions, "required_item", true) || view.Player.Resources["support"] != 2 || view.Preparation.TotalScore != 5 {
		t.Fatalf("trust action seat did not create usable preparation: player=%+v preparation=%+v", view.Player, view.Preparation)
	}
	trustProgresses := 0
	for _, progress := range view.RouteProgresses {
		if progress.ID == "trust" {
			trustProgresses++
		}
	}
	if trustProgresses != 1 {
		t.Fatalf("completed trust route rendered %d competing statuses: %+v", trustProgresses, view.RouteProgresses)
	}
	for _, wantDay := range []int{17, 19, 21} {
		view, err = session.Execute("wait:next")
		if err != nil {
			t.Fatal(err)
		}
		if view.Day != wantDay {
			t.Fatalf("advance stopped on day %d, want %d", view.Day, wantDay)
		}
		if wantDay == 17 && !containsMessage(view.LastTurn.Messages, "第一批参与者开始向黑风谷移动") {
			t.Fatalf("day 17 feedback omitted route signal: %+v", view.LastTurn)
		}
	}
	if view.Ending == nil || !strings.Contains(view.Outcome, "沈砚秋") || !hasDecisionChange(view.Ending.Influence, "沈砚秋", "F01", 5) {
		t.Fatalf("messenger influence = %+v", view.Ending)
	}
	if !containsMessage(view.Ending.PlayerConsequences, "行动席位") || view.Player.Resources["credit"] != 6 || view.Player.Resources["support"] != 3 {
		t.Fatalf("trusted intelligence produced no personal return: ending=%+v player=%+v", view.Ending.PlayerConsequences, view.Player)
	}
	if !containsMessage(view.Ending.Highlights, "改变了 3 个关键选择") {
		t.Fatalf("messenger ending omitted causal summary: %+v", view.Ending.Highlights)
	}
	if len(view.Ending.ActorPlanChanges) == 0 || !containsMessage(view.Ending.ActorPlanChanges, "原本准备") || !containsMessage(view.Ending.ActorPlanChanges, "后来改为") {
		t.Fatalf("messenger ending omitted actor plan changes: %+v", view.Ending.ActorPlanChanges)
	}
	if view.Metrics.VisibleDecisionChanges < 1 || view.Metrics.CoreResultDay != 21 || view.Metrics.DecisionInputs != 13 || view.Metrics.AutoAdvancedDays != 16 {
		t.Fatalf("messenger metrics = %+v", view.Metrics)
	}
	assertNoInternalFactIDsInPlayerText(t, view)
}

func assertNoInternalFactIDsInPlayerText(t *testing.T, view PlayerView) {
	t.Helper()
	texts := []string{view.Outcome}
	texts = append(texts, view.Guidance...)
	for _, event := range view.RecentEvents {
		texts = append(texts, event.Description)
	}
	for _, actor := range view.WorldMap.Actors {
		texts = append(texts, actor.Plan, actor.Reason, actor.PreviousPlan)
	}
	appendInfluence := func(influences []VisibleInfluence) {
		for _, influence := range influences {
			texts = append(texts, influence.Summary)
			for _, change := range influence.Changes {
				texts = append(texts, change.WithoutInformation, change.WithInformation)
			}
		}
	}
	appendInfluence(view.CausalThreads)
	if view.LastTurn != nil {
		texts = append(texts, view.LastTurn.Action, view.LastTurn.StopReason)
		texts = append(texts, view.LastTurn.Messages...)
		texts = append(texts, view.LastTurn.Journal...)
		appendInfluence(view.LastTurn.Influence)
	}
	if view.Ending != nil {
		texts = append(texts, view.Ending.Outcome)
		texts = append(texts, view.Ending.Coda...)
		texts = append(texts, view.Ending.PlayerConsequences...)
		texts = append(texts, view.Ending.Review...)
		texts = append(texts, view.Ending.Highlights...)
		texts = append(texts, view.Ending.ActorPlanChanges...)
		appendInfluence(view.Ending.Influence)
	}
	internalFactID := regexp.MustCompile(`\bF\d{2,}\b`)
	for _, text := range texts {
		if internalFactID.MatchString(text) {
			t.Fatalf("player-facing text leaked an internal fact id: %q", text)
		}
	}
}

func actionIDs(actions []AvailableAction) map[string]bool {
	result := make(map[string]bool, len(actions))
	for _, action := range actions {
		result[action.ID] = true
	}
	return result
}

func mapActorPlan(plans []VisibleActorPlan, actorID string) *VisibleActorPlan {
	for index := range plans {
		if plans[index].ID == actorID {
			return &plans[index]
		}
	}
	return nil
}

func itemAmount(items []VisibleItem, id string) int {
	for _, item := range items {
		if item.ID == id {
			return item.Amount
		}
	}
	return 0
}

func beliefConfidence(beliefs []VisibleBelief, id string) int {
	for _, belief := range beliefs {
		if belief.FactID == id {
			return belief.Confidence
		}
	}
	return 0
}

func containsMessage(messages []string, fragment string) bool {
	for _, message := range messages {
		if strings.Contains(message, fragment) {
			return true
		}
	}
	return false
}

func travelCheckReady(checks []TravelCheck, fragment string, ready bool) bool {
	for _, check := range checks {
		if strings.Contains(check.Label, fragment) && check.Ready == ready {
			return true
		}
	}
	return false
}

func preparationFactorReady(factors []PreparationFactor, key string, ready bool) bool {
	for _, factor := range factors {
		if factor.Key == key && factor.Ready == ready && factor.Label != "" && factor.Status != "" {
			return true
		}
	}
	return false
}

func executeMany(t *testing.T, session *Session, actions []string) {
	t.Helper()
	for index, action := range actions {
		if _, err := session.Execute(action); err != nil {
			t.Fatalf("turn %d execute %s: %v", index+1, action, err)
		}
	}
}

func executeUntilResolved(t *testing.T, session *Session) {
	t.Helper()
	for !session.View().Resolved {
		if _, err := session.Execute("wait"); err != nil {
			t.Fatalf("wait until resolution: %v", err)
		}
	}
}

func hasDecisionChange(influences []VisibleInfluence, actorName, factID string, day int) bool {
	for _, influence := range influences {
		if influence.ActorName != actorName || influence.FactID != factID {
			continue
		}
		for _, change := range influence.Changes {
			if change.Day == day && change.WithInformation != "" && change.WithoutInformation != "" {
				return true
			}
		}
	}
	return false
}

func hasCausalStage(influences []VisibleInfluence, actorName, factID, stage string) bool {
	for _, influence := range influences {
		if influence.ActorName == actorName && influence.FactID == factID && influence.Stage == stage && influence.StageLabel != "" && influence.Summary != "" {
			return true
		}
	}
	return false
}

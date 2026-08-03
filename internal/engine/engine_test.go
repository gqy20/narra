package engine

import (
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"fantu/internal/domain"
	"fantu/internal/scenario"
)

func loadBlackwind(t testing.TB) domain.Bundle {
	t.Helper()
	bundle, err := scenario.Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("load blackwind: %v", err)
	}
	return bundle
}

func TestT00ProducesExpectedBaseline(t *testing.T) {
	bundle := loadBlackwind(t)
	state, err := New(bundle).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if state.Day != 30 {
		t.Fatalf("final day = %d, want 30", state.Day)
	}
	if !strings.Contains(state.Outcome, "李玄") {
		t.Fatalf("outcome = %q, want Li Xuan baseline", state.Outcome)
	}
	if owner := state.Items["qingsuizhi"]; owner != "N01" {
		t.Fatalf("qingsuizhi owner = %q, want N01", owner)
	}
	if !state.ActorFlag("N05", "chen_ambushed") {
		t.Fatal("Chen Qingshan was not ambushed in the baseline")
	}
	if injury := state.NPCs["N02"].Injury; injury != 1 {
		t.Fatalf("Chen Qingshan injury = %d, want 1 after post-ambush replanning and recovery", injury)
	}
}

func TestSimulationIsDeterministic(t *testing.T) {
	bundle := loadBlackwind(t)
	first, err := New(bundle).Run()
	if err != nil {
		t.Fatalf("first Run() error = %v", err)
	}
	second, err := New(bundle).Run()
	if err != nil {
		t.Fatalf("second Run() error = %v", err)
	}
	if !reflect.DeepEqual(first, second) {
		t.Fatal("identical inputs produced different world states")
	}
}

func TestEngineLoadsInitialDirectionalRelations(t *testing.T) {
	bundle := loadBlackwind(t)
	bundle.InitialRelations = []domain.Relation{{From: "N01", To: "N03", Trust: 2, Suspicion: 1}}
	state := New(bundle).State()
	relation := state.RelationBetween("N01", "N03")
	if relation.From != "N01" || relation.To != "N03" || relation.Trust != 2 || relation.Suspicion != 1 {
		t.Fatalf("initial relation = %#v", relation)
	}
	if reverse := state.RelationBetween("N03", "N01"); reverse.From != "" {
		t.Fatalf("directional relation leaked to reverse edge: %#v", reverse)
	}
}

func TestPlannedCommandUsesFallbackWhenConditionsFail(t *testing.T) {
	bundle := loadBlackwind(t)
	plan, err := scenario.LoadPlan(filepath.Join("..", "..", "testdata", "T06_betray_li.json"), bundle)
	if err != nil {
		t.Fatalf("load T06: %v", err)
	}
	plan.Player.Resources["combat"] = 0
	state, err := NewWithPlan(bundle, plan).Run()
	if err != nil {
		t.Fatalf("fallback run failed: %v", err)
	}
	if state.Items["qingsuizhi"] == plan.Player.ID {
		t.Fatal("test setup unexpectedly let player win qingsuizhi")
	}
	if _, ok := state.Opportunities["trace_qingsuizhi_owner"]; !ok {
		t.Fatal("fallback did not open trace opportunity")
	}
	var skipped, fallbackCompleted bool
	for _, event := range state.Events {
		if event.Type == "player_command_skipped" && event.CauseID == "T06-command-07" {
			skipped = true
		}
		if event.Type == "player_action" && event.CauseID == "T06-command-07-fallback" {
			fallbackCompleted = true
		}
	}
	if !skipped || !fallbackCompleted {
		t.Fatalf("fallback event chain missing: skipped=%v completed=%v", skipped, fallbackCompleted)
	}
}

func TestPlannedCommandCanSkipFailedConditions(t *testing.T) {
	bundle := loadBlackwind(t)
	plan, err := scenario.LoadPlan(filepath.Join("..", "..", "testdata", "T06_betray_li.json"), bundle)
	if err != nil {
		t.Fatalf("load T06: %v", err)
	}
	plan.Player.Resources["combat"] = 0
	last := &plan.Commands[len(plan.Commands)-1]
	last.OnFailure = "skip"
	last.Fallback = nil
	state, err := NewWithPlan(bundle, plan).Run()
	if err != nil {
		t.Fatalf("skip run failed: %v", err)
	}
	for _, event := range state.Events {
		if event.Type == "player_action" && event.CauseID == last.ID {
			t.Fatal("skipped command unexpectedly completed")
		}
	}
}

func TestBeliefConditionCannotReadWorldTruth(t *testing.T) {
	state := &domain.WorldState{
		Facts:      map[string]domain.Fact{"F01": {ID: "F01", Truth: "true"}},
		WorldFlags: map[string]bool{}, ActorFlags: map[string]map[string]bool{},
	}
	npc := &domain.NPCState{Beliefs: map[string]domain.Belief{}, Items: map[string]int{}, Resources: map[string]int{}}
	condition := []domain.Condition{{Type: "belief", Key: "F01", MinConfidence: 1}}
	if conditionsMet(state, npc, condition) {
		t.Fatal("belief condition passed by reading world truth")
	}
	npc.Beliefs["F01"] = domain.Belief{FactID: "F01", Confidence: 1}
	if !conditionsMet(state, npc, condition) {
		t.Fatal("belief condition failed after NPC learned the fact")
	}
}

func TestUniqueItemInvariantRejectsDuplicateInventory(t *testing.T) {
	bundle := loadBlackwind(t)
	state := New(bundle).state
	state.Items["qingsuizhi"] = "N01"
	state.NPCs["N01"].Items["qingsuizhi"] = 1
	state.NPCs["N02"].Items["qingsuizhi"] = 1
	if err := ValidateState(state, bundle); err == nil {
		t.Fatal("ValidateState() accepted duplicated unique item")
	}
}

func TestT01PlayerIntelChangesOutcome(t *testing.T) {
	bundle := loadBlackwind(t)
	plan, err := scenario.LoadPlan(filepath.Join("..", "..", "testdata", "T01_sell_intel.json"), bundle)
	if err != nil {
		t.Fatalf("load T01 plan: %v", err)
	}
	state, err := NewWithPlan(bundle, plan).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if owner := state.Items["qingsuizhi"]; owner != "N03" {
		t.Fatalf("qingsuizhi owner = %q, want N03 after early intel", owner)
	}
	if !strings.Contains(state.Outcome, "沈砚秋") {
		t.Fatalf("outcome = %q, want Shen Yanqiu", state.Outcome)
	}
	if got := state.Player.Resources["spirit_stones"]; got != 130 {
		t.Fatalf("player spirit stones = %d, want 130", got)
	}
	if !state.ActorFlag("N03", "prepared") {
		t.Fatal("Shen Yanqiu did not prepare after receiving early intelligence")
	}
	foundPlayerEvent := false
	for _, event := range state.Events {
		if event.Type == "player_action" && event.CauseID == "T01-command-02" {
			foundPlayerEvent = true
			break
		}
	}
	if !foundPlayerEvent {
		t.Fatal("player action was not recorded as a world event")
	}
}

func TestT02TransplantAvoidsMatureContest(t *testing.T) {
	bundle := loadBlackwind(t)
	plan, err := scenario.LoadPlan(filepath.Join("..", "..", "testdata", "T02_transplant.json"), bundle)
	if err != nil {
		t.Fatalf("load T02 plan: %v", err)
	}
	state, err := NewWithPlan(bundle, plan).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if owner := state.Items["qingsuizhi"]; owner != "N06" {
		t.Fatalf("qingsuizhi owner = %q, want N06 after transplant", owner)
	}
	if owner := state.Items["jade_box"]; owner != "N06" {
		t.Fatalf("jade box owner = %q, want N06", owner)
	}
	if !strings.Contains(state.Outcome, "合作") || !strings.Contains(state.Outcome, "成熟日前") {
		t.Fatalf("outcome = %q, want cooperative early transplant", state.Outcome)
	}
	if !state.ActorFlag("P00", "owes_chen_favor") {
		t.Fatal("player did not retain the social cost of borrowing the jade box")
	}
	transplantedOnDay20 := false
	for _, event := range state.Events {
		if event.Day == 20 && strings.Contains(event.Description, "提前移植") {
			transplantedOnDay20 = true
			break
		}
	}
	if !transplantedOnDay20 {
		t.Fatal("transplant was not recorded on day 20")
	}
}

func TestT03PublicInjuryCreatesAlliance(t *testing.T) {
	bundle := loadBlackwind(t)
	plan, err := scenario.LoadPlan(filepath.Join("..", "..", "testdata", "T03_reveal_injury.json"), bundle)
	if err != nil {
		t.Fatalf("load T03 plan: %v", err)
	}
	state, err := NewWithPlan(bundle, plan).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if owner := state.Items["qingsuizhi"]; owner != "N03" {
		t.Fatalf("qingsuizhi owner = %q, want N03 after alliance", owner)
	}
	if !state.WorldFlag("N02_withdrawn") {
		t.Fatal("Chen Qingshan did not withdraw after his injury became public")
	}
	if state.NPCs["N02"].Location != "L03" {
		t.Fatalf("Chen Qingshan location = %s, want L03", state.NPCs["N02"].Location)
	}
	if injury := state.NPCs["N02"].Injury; injury != 1 {
		t.Fatalf("Chen Qingshan injury = %d, want 1 after withdrawal and recovery", injury)
	}
	if !state.WorldFlag("qinglan_chen_alliance") {
		t.Fatal("Qinglan-Chen alliance was not formed")
	}
	if !state.WorldFlag("chen_suspects_player") {
		t.Fatal("player did not retain the consequence of exposing Chen private information")
	}
	if !strings.Contains(state.Outcome, "合作") {
		t.Fatalf("outcome = %q, want cooperative outcome", state.Outcome)
	}
}

func TestT04StrongFalseDateDelaysCompetitorAndCostsCredit(t *testing.T) {
	bundle := loadBlackwind(t)
	plan, err := scenario.LoadPlan(filepath.Join("..", "..", "testdata", "T04_false_date.json"), bundle)
	if err != nil {
		t.Fatalf("load T04 plan: %v", err)
	}
	state, err := NewWithPlan(bundle, plan).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if owner := state.Items["qingsuizhi"]; owner != "N01" {
		t.Fatalf("qingsuizhi owner = %q, want N01 while Qinglan is delayed", owner)
	}
	if location := state.NPCs["N03"].Location; location != "L02" {
		t.Fatalf("Shen Yanqiu location = %s, want L02 after trusting false date", location)
	}
	belief := state.NPCs["N03"].Beliefs["F02"]
	if belief.Confidence != 3 || belief.Source != "P00" {
		t.Fatalf("Shen Yanqiu false belief = %+v, want confidence 3 sourced to player", belief)
	}
	for _, decision := range state.Decisions {
		for _, choice := range decision.Choices {
			if decision.ActorID == "N03" && choice.StrategyID == "N03-verify-date" {
				t.Fatal("Shen Yanqiu verified a rumor he considered fully credible")
			}
		}
	}
	if got := state.Player.Resources["credit"]; got != 0 {
		t.Fatalf("player credit = %d, want 0 after rumor exposure", got)
	}
	if !state.WorldFlag("false_rumor_exposed") {
		t.Fatal("false rumor was not exposed in the aftermath")
	}
}

func TestMergeBeliefDoesNotDowngradeConfidence(t *testing.T) {
	beliefs := map[string]domain.Belief{
		"F01": {FactID: "F01", Confidence: 3, Source: "verified"},
	}
	mergeBelief(beliefs, domain.Belief{FactID: "F01", Confidence: 1, Source: "rumor"})
	if got := beliefs["F01"]; got.Confidence != 3 || got.Source != "verified" {
		t.Fatalf("strong belief was downgraded: %+v", got)
	}
}

func TestMergeBeliefPreservesConflictingEvidenceAndUsesStrength(t *testing.T) {
	beliefs := map[string]domain.Belief{
		"F01": {FactID: "F01", Claim: "第24天", Confidence: 3, EvidenceStrength: 2, Source: "rumor"},
	}
	mergeBelief(beliefs, domain.Belief{FactID: "F01", Claim: "第22天", Confidence: 2, EvidenceStrength: 4, Source: "ledger"})
	got := beliefs["F01"]
	if got.Claim != "第22天" || got.Source != "ledger" || !got.Contested || len(got.Evidence) != 2 {
		t.Fatalf("merged belief = %+v, want stronger claim with two conflicting evidence entries", got)
	}
	mergeBelief(beliefs, domain.Belief{FactID: "F01", Claim: "第25天", Confidence: 3, EvidenceStrength: 1, Source: "hearsay"})
	got = beliefs["F01"]
	if got.Claim != "第22天" || len(got.Evidence) != 3 {
		t.Fatalf("weaker contradiction changed adopted claim or was lost: %+v", got)
	}
}

func TestT05EvidencePreventsAmbushAndChangesSuccession(t *testing.T) {
	bundle := loadBlackwind(t)
	plan, err := scenario.LoadPlan(filepath.Join("..", "..", "testdata", "T05_expose_betrayal.json"), bundle)
	if err != nil {
		t.Fatalf("load T05 plan: %v", err)
	}
	state, err := NewWithPlan(bundle, plan).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if owner := state.Items["qingsuizhi"]; owner != "N02" {
		t.Fatalf("qingsuizhi owner = %q, want N02 after protected route", owner)
	}
	if owner := state.Items["chen_letter"]; owner != "P00" {
		t.Fatalf("Chen letter owner = %q, want player evidence", owner)
	}
	if !state.WorldFlag("N07_disinherited") || !state.WorldFlag("N07_fugitive") {
		t.Fatal("Chen Yuheng succession consequences were not applied")
	}
	if location := state.NPCs["N07"].Location; location != "L01" {
		t.Fatalf("Chen Yuheng location = %s, want L01 after fleeing", location)
	}
	if injury := state.NPCs["N02"].Injury; injury != 1 {
		t.Fatalf("Chen Qingshan injury = %d, want 1 after protected route and recovery", injury)
	}
	for _, event := range state.Events {
		if event.ActorID == "N05" && strings.Contains(event.Description, "伏击陈氏") {
			t.Fatal("Wang Heng ambushed a caravan after its route changed")
		}
	}
	if !strings.Contains(state.Outcome, "避开伏击") || strings.Contains(state.Outcome, "玩家") {
		t.Fatalf("outcome = %q, want protected caravan outcome", state.Outcome)
	}
	if got := state.Player.Resources["credit"]; got != 2 {
		t.Fatalf("player credit = %d, want 2 after protecting Chen caravan", got)
	}
	relation := state.RelationBetween("N02", "P00")
	if relation.Trust != 3 || relation.Debt != 1 {
		t.Fatalf("Chen-to-player relation = %+v, want trust 3 and debt 1", relation)
	}
}

func TestT06BetrayalCreatesRevengeAfterPlayerWins(t *testing.T) {
	bundle := loadBlackwind(t)
	plan, err := scenario.LoadPlan(filepath.Join("..", "..", "testdata", "T06_betray_li.json"), bundle)
	if err != nil {
		t.Fatalf("load T06 plan: %v", err)
	}
	state, err := NewWithPlan(bundle, plan).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if owner := state.Items["qingsuizhi"]; owner != "P00" {
		t.Fatalf("qingsuizhi owner = %q, want player", owner)
	}
	if state.Player.Items["qingsuizhi"] != 1 {
		t.Fatal("player inventory does not contain qingsuizhi")
	}
	if !state.WorldFlag("li_betrayed") || !state.WorldFlag("li_hunts_player") {
		t.Fatal("Li Xuan revenge chain was not created")
	}
	if state.WorldFlag("li_player_pact") {
		t.Fatal("broken pact remained active")
	}
	if got := state.Player.Resources["credit"]; got != 0 {
		t.Fatalf("player credit = %d, want 0 after betrayal", got)
	}
	relation := state.RelationBetween("N01", "P00")
	if relation.Trust != -2 || relation.Suspicion != 3 || relation.Hatred != 3 {
		t.Fatalf("Li-to-player relation after betrayal = %+v", relation)
	}
	if !strings.Contains(state.Outcome, "违背分配约定") || !strings.Contains(state.Outcome, "追偿") {
		t.Fatalf("outcome = %q, want betrayal and revenge", state.Outcome)
	}
	foundHunt := false
	for _, event := range state.Events {
		if event.ActorID == "N01" && strings.Contains(event.Description, "追踪") {
			foundHunt = true
			break
		}
	}
	if !foundHunt {
		t.Fatal("Li Xuan did not produce a pursuit event")
	}
}

func TestT07FailureCreatesRecoveryAndFollowUpOptions(t *testing.T) {
	bundle := loadBlackwind(t)
	plan, err := scenario.LoadPlan(filepath.Join("..", "..", "testdata", "T07_failed_ambush.json"), bundle)
	if err != nil {
		t.Fatalf("load T07 plan: %v", err)
	}
	state, err := NewWithPlan(bundle, plan).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if state.Day != 30 {
		t.Fatalf("simulation ended on day %d after failure, want day 30", state.Day)
	}
	if !state.WorldFlag("player_ambush_failed") || !state.WorldFlag("player_recovered") {
		t.Fatal("failure and recovery states were not both recorded")
	}
	if !state.WorldFlag("owes_qinglan_favor") {
		t.Fatal("recovery did not create a Qinglan favor debt")
	}
	if injury := state.Player.Injury; injury != 0 {
		t.Fatalf("player injury = %d, want 0 after treatment", injury)
	}
	if state.Player.Items["healing_pill"] != 0 || state.NPCs["N05"].Items["healing_pill"] != 1 {
		t.Fatal("lost healing pill was not transferred to Wang Heng")
	}
	if _, ok := state.Opportunities["track_lost_pill"]; !ok {
		t.Fatal("failure did not leave a follow-up opportunity to recover the lost item")
	}
	if _, ok := state.Opportunities["treat_injury"]; ok {
		t.Fatal("completed treatment opportunity remained open")
	}
	if _, ok := state.Opportunities["seek_help"]; ok {
		t.Fatal("completed help opportunity remained open")
	}
	if debt := state.RelationBetween("P00", "N03").Debt; debt != 1 {
		t.Fatalf("player debt to Qinglan = %d, want 1", debt)
	}
	failureDay, recoveryDay := 0, 0
	for _, event := range state.Events {
		if event.ActorID == "P00" && strings.Contains(event.Description, "伏击失败") {
			failureDay = event.Day
		}
		if event.ActorID == "P00" && strings.Contains(event.Description, "治疗重伤") {
			recoveryDay = event.Day
		}
	}
	if failureDay != 3 || recoveryDay != 8 {
		t.Fatalf("failure/recovery days = %d/%d, want 3/8", failureDay, recoveryDay)
	}
}

func TestStepAcceptsRuntimeCommandsAndExposesSnapshot(t *testing.T) {
	bundle := loadBlackwind(t)
	plan, err := scenario.LoadPlan(filepath.Join("..", "..", "testdata", "T01_sell_intel.json"), bundle)
	if err != nil {
		t.Fatalf("load T01 plan: %v", err)
	}
	simulation := NewWithPlayer(bundle, plan.Player)

	day1, err := simulation.Step([]domain.PlayerCommand{plan.Commands[0]})
	if err != nil {
		t.Fatalf("day 1 Step() error = %v", err)
	}
	if day1.Day != 1 || day1.Player.Location != "L02" {
		t.Fatalf("day 1 state = day %d location %s", day1.Day, day1.Player.Location)
	}
	if _, known := day1.NPCs["N03"].Beliefs["F01"]; known {
		t.Fatal("Shen Yanqiu learned F01 before the runtime sell command")
	}

	day2, err := simulation.Step([]domain.PlayerCommand{plan.Commands[1]})
	if err != nil {
		t.Fatalf("day 2 Step() error = %v", err)
	}
	belief := day2.NPCs["N03"].Beliefs["F01"]
	if belief.Confidence != 3 || belief.Source != "P00" {
		t.Fatalf("runtime command produced belief %+v", belief)
	}

	day3, err := simulation.Step(nil)
	if err != nil {
		t.Fatalf("day 3 Step() error = %v", err)
	}
	if day3.NPCs["N03"].Pending == nil || day3.NPCs["N03"].Pending.Intent.Strategy.ID != "N03-check-player-source" {
		t.Fatalf("NPC did not react by checking an untrusted runtime source: %+v", day3.NPCs["N03"].Pending)
	}

	day3.NPCs["N01"].Location = "tampered"
	if got := simulation.State().NPCs["N01"].Location; got == "tampered" {
		t.Fatal("State() exposed mutable engine state")
	}
}

func TestStepRejectsCommandForWrongDay(t *testing.T) {
	bundle := loadBlackwind(t)
	plan, err := scenario.LoadPlan(filepath.Join("..", "..", "testdata", "T01_sell_intel.json"), bundle)
	if err != nil {
		t.Fatalf("load T01 plan: %v", err)
	}
	simulation := NewWithPlayer(bundle, plan.Player)
	wrongDay := plan.Commands[1]
	if _, err := simulation.Step([]domain.PlayerCommand{wrongDay}); err == nil {
		t.Fatal("Step() accepted a day 2 command on day 1")
	}
	if got := simulation.State().Day; got != 0 {
		t.Fatalf("failed step advanced world to day %d, want rollback to day 0", got)
	}
}

func TestMultiDayActionDelaysEffectsAndBlocksNewCommand(t *testing.T) {
	bundle := loadBlackwind(t)
	plan, err := scenario.LoadPlan(filepath.Join("..", "..", "testdata", "T07_failed_ambush.json"), bundle)
	if err != nil {
		t.Fatalf("load T07 plan: %v", err)
	}
	simulation := NewWithPlayer(bundle, plan.Player)

	day1, err := simulation.Step([]domain.PlayerCommand{plan.Commands[0]})
	if err != nil {
		t.Fatalf("start tracking: %v", err)
	}
	if day1.Player.Location != "L01" {
		t.Fatalf("multi-day movement applied early: location = %s", day1.Player.Location)
	}
	if day1.Player.Pending == nil || day1.Player.Pending.CompleteDay != 2 {
		t.Fatalf("pending action = %+v, want completion on day 2", day1.Player.Pending)
	}

	busyCommand := plan.Commands[1]
	busyCommand.Day = 2
	if _, err := simulation.Step([]domain.PlayerCommand{busyCommand}); err == nil {
		t.Fatal("busy player accepted another command")
	}
	if got := simulation.State().Day; got != 1 {
		t.Fatalf("failed busy step advanced world to day %d", got)
	}

	day2, err := simulation.Step(nil)
	if err != nil {
		t.Fatalf("complete tracking: %v", err)
	}
	if day2.Player.Location != "L04" || day2.Player.Pending != nil {
		t.Fatalf("completed movement state = location %s pending %+v", day2.Player.Location, day2.Player.Pending)
	}
}

func TestRelationshipModifierUsesDirectionalState(t *testing.T) {
	state := &domain.WorldState{Relations: map[string]domain.Relation{
		domain.RelationKey("N01", "P00"): {
			From: "N01", To: "P00", Trust: 3, Dependence: 1, Suspicion: 1, Hatred: 1,
		},
	}}
	if got, want := relationshipModifier(state, "N01", "P00"), 2; got != want {
		t.Fatalf("relationship modifier = %d, want %d", got, want)
	}
	if got := relationshipModifier(state, "P00", "N01"); got != 0 {
		t.Fatalf("reverse relationship modifier = %d, want 0", got)
	}
}

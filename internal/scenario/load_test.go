package scenario

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"fantu/internal/domain"
)

func TestOfficialContestOutcomesHideMechanicalScores(t *testing.T) {
	for _, world := range []string{"blackwind", "orbital"} {
		bundle, err := Load(filepath.Join("..", "..", "data", world))
		if err != nil {
			t.Fatalf("load %s: %v", world, err)
		}
		texts := []string{
			bundle.Scenario.Title,
			bundle.Scenario.Contest.EarlyOutcome,
			bundle.Scenario.Contest.NoWinnerOutcome,
			bundle.Scenario.Contest.DefaultOutcome,
		}
		for _, rule := range bundle.Scenario.Contest.OutcomeRules {
			texts = append(texts, rule.Template)
		}
		for _, text := range texts {
			if strings.Contains(text, "准备值") || strings.Contains(text, "玩家保护") || strings.Contains(text, "无玩家基线") {
				t.Fatalf("%s exposes implementation language in %q", world, text)
			}
		}
	}
}

func TestOrbitalContentHasNoBlackwindTerminology(t *testing.T) {
	paths, err := filepath.Glob(filepath.Join("..", "..", "data", "orbital", "*.yml"))
	if err != nil {
		t.Fatal(err)
	}
	forbidden := []string{"青岚", "黑风谷", "青髓芝", "解瘴丹", "灵石", "宗门", "散修", "开谷", "借丹", "药理", "药典", "灵药", "药商", "药材", "门内", "弟子", "瘴气", "家主", "移植", "决策窗口", "财团财团", "静心吐纳", "收入行囊"}
	for _, path := range paths {
		data, err := os.ReadFile(path)
		if err != nil {
			t.Fatal(err)
		}
		for _, term := range forbidden {
			if strings.Contains(string(data), term) {
				t.Errorf("%s contains blackwind term %q", filepath.Base(path), term)
			}
		}
	}
}

func TestLoadBlackwindBundle(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if got, want := len(bundle.NPCs), 10; got != want {
		t.Fatalf("NPC count = %d, want %d", got, want)
	}
	if got, want := len(bundle.Actions), 15; got != want {
		t.Fatalf("action count = %d, want %d", got, want)
	}
	if got, want := len(bundle.Facts), 10; got != want {
		t.Fatalf("fact count = %d, want %d", got, want)
	}
	if got, want := len(bundle.Scenario.Directives), 3; got != want {
		t.Fatalf("world directive count = %d, want %d", got, want)
	}
	if got, want := len(bundle.Scenario.Opportunities), 1; got != want {
		t.Fatalf("opportunity action count = %d, want %d", got, want)
	}
	if len(bundle.Scenario.Markets) == 0 || bundle.Scenario.Markets[0].Currency != "spirit_stones" {
		t.Fatalf("market currency = %+v", bundle.Scenario.Markets)
	}
	if bundle.Content.SchemaVersion != CurrentSchemaVersion || bundle.Content.Version != "1.6.0" || !strings.HasPrefix(bundle.Content.Hash, "sha256:") {
		t.Fatalf("content metadata = %+v", bundle.Content)
	}
	if bundle.Presentation.Brand != "凡途" || bundle.Presentation.WorldTitle != "黑风谷山川" || len(bundle.Presentation.Resources) != 4 || len(bundle.Presentation.Locations) != 5 || len(bundle.Presentation.Actors) != 10 {
		t.Fatalf("presentation metadata = %+v", bundle.Presentation)
	}
	if bundle.Dialogue.Context == "" || bundle.Dialogue.PlayerAddress != "道友" || bundle.Dialogue.Style == "" {
		t.Fatalf("dialogue metadata = %+v", bundle.Dialogue)
	}
	if len(bundle.Rules.FallbackStrategies) != 3 || !bundle.Rules.Investigation.Enabled || !bundle.Rules.Navigation.Contest.Enabled {
		t.Fatalf("world rules = %+v", bundle.Rules)
	}
	if len(bundle.Rules.Player.Actions) != 2 || bundle.Rules.Player.Movement.ActionID != "explore" || bundle.Rules.Economy.AgreementCurrency != "spirit_stones" {
		t.Fatalf("player/economy rules = %+v / %+v", bundle.Rules.Player, bundle.Rules.Economy)
	}
	if arc, ok := bundle.StoryArcs["qinglan_intel"]; !ok || arc.InitialState != "uncommitted" || len(arc.Nodes) != 10 || len(arc.Nodes[0].Choices) != 3 || len(arc.ProgressRules) == 0 || len(arc.ConsequenceRules) == 0 {
		t.Fatalf("qinglan story arc = %+v", arc)
	}
	if arc, ok := bundle.StoryArcs["antidote_recovery"]; !ok || arc.InitialState != "available" || len(arc.Nodes) != 1 || arc.Nodes[0].Kind != "recover" {
		t.Fatalf("antidote recovery arc = %+v", arc)
	}
	if len(bundle.Scenario.Contest.OutcomeRules) != 2 || len(bundle.Scenario.Contest.RewardRules) != 1 {
		t.Fatalf("contest content rules = %+v / %+v", bundle.Scenario.Contest.OutcomeRules, bundle.Scenario.Contest.RewardRules)
	}
	if bundle.DefaultPlayer.ID != "P00" || bundle.DefaultPlayer.Name != "无名散修" || bundle.DefaultPlayer.Location != "L01" {
		t.Fatalf("default player = %+v", bundle.DefaultPlayer)
	}
	for _, npc := range bundle.NPCs {
		if npc.PublicProfile == "" || npc.PublicRole == "" || len(npc.PublicInterests) == 0 || npc.PublicRisk == "" {
			t.Fatalf("NPC %s lacks complete public decision context", npc.ID)
		}
	}
}

func TestDialogueAndPresentationPoliciesAreScenarioAuthored(t *testing.T) {
	blackwind, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatal(err)
	}
	tianqi, err := Load(filepath.Join("..", "..", "data", "tianqi"))
	if err != nil {
		t.Fatal(err)
	}
	if blackwind.Dialogue.ConfidenceLabels.Rumored != "只是听说" || tianqi.Dialogue.ConfidenceLabels.Rumored != "仅是传言" {
		t.Fatalf("scenario confidence language was not loaded: blackwind=%+v tianqi=%+v", blackwind.Dialogue.ConfidenceLabels, tianqi.Dialogue.ConfidenceLabels)
	}
	if blackwind.Presentation.UI["default_player_name"] != "无名修士" || tianqi.Presentation.UI["default_player_name"] != "无名抄手" || blackwind.Presentation.UI["term_clue"] == tianqi.Presentation.UI["term_clue"] {
		t.Fatalf("scenario UI terminology was not loaded: blackwind=%v tianqi=%v", blackwind.Presentation.UI, tianqi.Presentation.UI)
	}
	if blackwind.Presentation.Locations["qinglan"].FallbackKind != "camp" || blackwind.Presentation.Locations["qinglan"].AmbientFrequency != 72 {
		t.Fatalf("location fallback presentation was not loaded: %+v", blackwind.Presentation.Locations["qinglan"])
	}
	if len(tianqi.Presentation.Prologue.Beats) != 5 || tianqi.Presentation.Prologue.Beats[0].Font != "display" || tianqi.Presentation.Prologue.Beats[0].FontSize != 40 || tianqi.Presentation.Prologue.Beats[0].Position != "center" || !tianqi.Presentation.Prologue.Beats[4].AwaitInput {
		t.Fatalf("tianqi prologue presentation was not loaded: %+v", tianqi.Presentation.Prologue)
	}
}

func TestValidateRejectsInvalidPrologueTypography(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "tianqi"))
	if err != nil {
		t.Fatal(err)
	}
	bundle.Presentation.Prologue.Beats[0].Position = "top_right"
	if err := Validate(bundle); err == nil || !strings.Contains(err.Error(), "invalid position") {
		t.Fatalf("invalid prologue position error = %v", err)
	}
}

func TestValidateRejectsInvalidWorldRuleReference(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatal(err)
	}
	bundle.Rules.Navigation.Contest.KnowledgeFacts = append(bundle.Rules.Navigation.Contest.KnowledgeFacts, "missing-fact")
	if err := Validate(bundle); err == nil || !strings.Contains(err.Error(), "contest navigation references unknown fact") {
		t.Fatalf("invalid world rule error = %v", err)
	}
}

func TestValidateRejectsInvalidPlayerRuleCurrency(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatal(err)
	}
	bundle.Rules.Player.Actions[1].RepeatCost.Resource = "missing-resource"
	if err := Validate(bundle); err == nil || !strings.Contains(err.Error(), "repeat cost references unknown player resource") {
		t.Fatalf("invalid player rule error = %v", err)
	}
}

func TestValidateRejectsUnsafeScenarioID(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatal(err)
	}
	bundle.Scenario.ID = "../other-story"
	if err := Validate(bundle); err == nil || !strings.Contains(err.Error(), "scenario id") {
		t.Fatalf("unsafe scenario id error = %v", err)
	}
}

func TestDecodeYAMLUsesJSONFieldNamesAndRejectsUnknownFields(t *testing.T) {
	var scenario domain.Scenario
	if err := decodeYAML([]byte("id: sample\nplanning_mode: unified_score\nduration: 2\n"), &scenario); err != nil {
		t.Fatalf("decode valid YAML: %v", err)
	}
	if scenario.ID != "sample" || scenario.PlanningMode != "unified_score" || scenario.Duration != 2 {
		t.Fatalf("decoded scenario = %+v", scenario)
	}
	if err := decodeYAML([]byte("id: sample\nunknown_field: true\n"), &scenario); err == nil || !strings.Contains(err.Error(), "unknown field") {
		t.Fatalf("unknown YAML field error = %v", err)
	}
}

func TestDecodeYAMLRejectsDuplicateKeysAndDocuments(t *testing.T) {
	var scenario domain.Scenario
	if err := decodeYAML([]byte("id: one\nid: two\n"), &scenario); err == nil {
		t.Fatal("duplicate YAML key was accepted")
	}
	if err := decodeYAML([]byte("id: one\n---\nid: two\n"), &scenario); err == nil || !strings.Contains(err.Error(), "multiple documents") {
		t.Fatalf("multiple YAML document error = %v", err)
	}
}

func TestLoadT01Plan(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	plan, err := LoadPlan(filepath.Join("..", "..", "testdata", "T01_sell_intel.json"), bundle)
	if err != nil {
		t.Fatalf("LoadPlan() error = %v", err)
	}
	if got, want := len(plan.Commands), 2; got != want {
		t.Fatalf("command count = %d, want %d", got, want)
	}
}

func TestLoadT02Plan(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	plan, err := LoadPlan(filepath.Join("..", "..", "testdata", "T02_transplant.json"), bundle)
	if err != nil {
		t.Fatalf("LoadPlan() error = %v", err)
	}
	if got, want := len(plan.Commands), 6; got != want {
		t.Fatalf("command count = %d, want %d", got, want)
	}
}

func TestLoadT03Plan(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	plan, err := LoadPlan(filepath.Join("..", "..", "testdata", "T03_reveal_injury.json"), bundle)
	if err != nil {
		t.Fatalf("LoadPlan() error = %v", err)
	}
	if got, want := len(plan.Commands), 1; got != want {
		t.Fatalf("command count = %d, want %d", got, want)
	}
}

func TestLoadT04Plan(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	plan, err := LoadPlan(filepath.Join("..", "..", "testdata", "T04_false_date.json"), bundle)
	if err != nil {
		t.Fatalf("LoadPlan() error = %v", err)
	}
	if got, want := len(plan.Commands), 4; got != want {
		t.Fatalf("command count = %d, want %d", got, want)
	}
}

func TestLoadT05Plan(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	plan, err := LoadPlan(filepath.Join("..", "..", "testdata", "T05_expose_betrayal.json"), bundle)
	if err != nil {
		t.Fatalf("LoadPlan() error = %v", err)
	}
	if got, want := len(plan.Commands), 4; got != want {
		t.Fatalf("command count = %d, want %d", got, want)
	}
}

func TestLoadT06Plan(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	plan, err := LoadPlan(filepath.Join("..", "..", "testdata", "T06_betray_li.json"), bundle)
	if err != nil {
		t.Fatalf("LoadPlan() error = %v", err)
	}
	if got, want := len(plan.Commands), 7; got != want {
		t.Fatalf("command count = %d, want %d", got, want)
	}
	last := plan.Commands[len(plan.Commands)-1]
	if last.OnFailure != "fallback" || last.Fallback == nil || last.Fallback.ActionID != "track" {
		t.Fatalf("T06 fallback not loaded: %#v", last)
	}
}

func TestLoadT07Plan(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	plan, err := LoadPlan(filepath.Join("..", "..", "testdata", "T07_failed_ambush.json"), bundle)
	if err != nil {
		t.Fatalf("LoadPlan() error = %v", err)
	}
	if got, want := len(plan.Commands), 4; got != want {
		t.Fatalf("command count = %d, want %d", got, want)
	}
}

func TestValidateCommandRejectsInvalidFallbackConfiguration(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	command := domain.PlayerCommand{ID: "broken", Day: 1, ActionID: "buy", OnFailure: "fallback"}
	if err := validateCommand(command, 1, "P00", bundle, 0); err == nil {
		t.Fatal("fallback policy without command should fail")
	}
	command.OnFailure = "sometimes"
	if err := validateCommand(command, 1, "P00", bundle, 0); err == nil {
		t.Fatal("unknown failure policy should fail")
	}
	command.OnFailure = "fallback"
	command.Fallback = &domain.PlayerCommand{ID: "wrong-day", Day: 2, ActionID: "track"}
	if err := validateCommand(command, 1, "P00", bundle, 0); err == nil {
		t.Fatal("fallback scheduled on a different day should fail")
	}
}

func TestValidateRejectsInvalidLocationRoutes(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	location := bundle.Locations["L01"]
	location.Routes = append(location.Routes, domain.Route{To: "missing", Duration: 1})
	bundle.Locations["L01"] = location
	if err := Validate(bundle); err == nil {
		t.Fatal("route to unknown location should fail validation")
	}

	bundle, err = Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("reload bundle: %v", err)
	}
	location = bundle.Locations["L01"]
	location.Routes[0].Duration = 0
	bundle.Locations["L01"] = location
	if err := Validate(bundle); err == nil {
		t.Fatal("zero-duration route should fail validation")
	}
}

func TestValidateRejectsInvalidInvestigationLead(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	fact := bundle.Facts["F02"]
	fact.Leads = append(fact.Leads, domain.FactLead{FactID: "missing", Confidence: 2})
	bundle.Facts["F02"] = fact
	if err := Validate(bundle); err == nil {
		t.Fatal("investigation lead to unknown fact should fail validation")
	}

	bundle, err = Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("reload bundle: %v", err)
	}
	fact = bundle.Facts["F02"]
	fact.Leads[0].Confidence = 4
	bundle.Facts["F02"] = fact
	if err := Validate(bundle); err == nil {
		t.Fatal("out-of-range investigation confidence should fail validation")
	}
}

func TestValidateRejectsInvalidExplicitCosts(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	bundle.NPCs[0].Strategies[0].Costs = map[string]int{"spirit_stones": 0}
	if err := Validate(bundle); err == nil {
		t.Fatal("zero explicit cost should fail validation")
	}
}

func TestValidateRejectsInvalidFlagScopeAndUniqueSource(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	bundle.NPCs[0].Strategies[0].Conditions[0].Scope = "galaxy"
	if err := Validate(bundle); err == nil {
		t.Fatal("invalid condition flag scope should fail")
	}

	bundle, err = Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("reload bundle: %v", err)
	}
	for i := range bundle.NPCs {
		for j := range bundle.NPCs[i].Strategies {
			for k := range bundle.NPCs[i].Strategies[j].Effects {
				effect := &bundle.NPCs[i].Strategies[j].Effects[k]
				if effect.Type == "transfer_unique" {
					effect.FromID = ""
					if err := Validate(bundle); err == nil {
						t.Fatal("unique transfer without from_id should fail")
					}
					return
				}
			}
		}
	}
	t.Fatal("test bundle contains no transfer_unique effect")
}

func TestValidateRejectsInvalidPlanningMode(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	bundle.Scenario.PlanningMode = "unknown"
	if err := Validate(bundle); err == nil {
		t.Fatal("Validate() accepted invalid planning mode")
	}
}

func TestValidateRejectsPrivateBroadcast(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	bundle.NPCs[0].Strategies[0].Effects = append(bundle.NPCs[0].Strategies[0].Effects, domain.Effect{
		Type: "set_belief", TargetID: "*", FactID: "F01", Confidence: 2, Propagation: "private",
	})
	if err := Validate(bundle); err == nil {
		t.Fatal("Validate() accepted private wildcard broadcast")
	}
}

func TestValidateRejectsUnknownDuplicateAndUnusedTopics(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	bundle.Facts["F01"] = domain.Fact{ID: "F01", Topics: []string{"unknown"}}
	if err := Validate(bundle); err == nil {
		t.Fatal("Validate() accepted undeclared topic")
	}

	bundle, _ = Load(filepath.Join("..", "..", "data", "blackwind"))
	bundle.NPCs[0].Interests = append(bundle.NPCs[0].Interests, bundle.NPCs[0].Interests[0])
	if err := Validate(bundle); err == nil {
		t.Fatal("Validate() accepted duplicate NPC topic")
	}

	bundle, _ = Load(filepath.Join("..", "..", "data", "blackwind"))
	bundle.Scenario.Topics = append(bundle.Scenario.Topics, "unused")
	if err := Validate(bundle); err == nil {
		t.Fatal("Validate() accepted unused declared topic")
	}
}

func TestValidateRejectsInvalidStructuredGoal(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	bundle.NPCs[0].Goals = append(bundle.NPCs[0].Goals, domain.Goal{Type: "conquer", Priority: 6})
	if err := Validate(bundle); err == nil {
		t.Fatal("Validate() accepted invalid goal type and priority")
	}
}

func TestValidateRejectsInvalidMarketDefinition(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	bundle.Scenario.Markets[0].Stock["antidote"] = -1
	if err := Validate(bundle); err == nil {
		t.Fatal("Validate() accepted negative market stock")
	}
}

func TestValidateRejectsUnboundedWorldDirective(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	bundle.Scenario.Directives[0].Effects = []domain.Effect{{Type: "adjust_resource", TargetID: "N01", Key: "combat", Amount: 10}}
	if err := Validate(bundle); err == nil {
		t.Fatal("Validate() accepted a director effect that directly changes an actor")
	}

	bundle, err = Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("reload bundle: %v", err)
	}
	bundle.Scenario.Directives[1].TargetID = "missing-market"
	if err := Validate(bundle); err == nil {
		t.Fatal("Validate() accepted a director trigger with an unknown market")
	}
}

func TestValidateRejectsUnknownPlayerResourceDirective(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	bundle.Scenario.Directives = append(bundle.Scenario.Directives, domain.WorldDirectiveDefinition{
		ID: "invalid-player-pressure", Description: "invalid", Trigger: "player_resource_at_least",
		Key: "missing-resource", MinValue: 2, Priority: 10, MaxUses: 1,
	})
	if err := Validate(bundle); err == nil {
		t.Fatal("Validate() accepted a directive with an unknown player resource")
	}
}

func TestValidateRejectsInvalidStoryTransition(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	arc := bundle.StoryArcs["qinglan_intel"]
	arc.Nodes[0].Choices[0].ToState = "missing"
	bundle.StoryArcs[arc.ID] = arc
	if err := Validate(bundle); err == nil || !strings.Contains(err.Error(), "invalid choice") {
		t.Fatalf("invalid story transition error = %v", err)
	}
}

func TestValidateRejectsTrackedNPCWithoutPublicGoal(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	for index := range bundle.NPCs {
		if bundle.NPCs[index].TrackPublicPlan {
			bundle.NPCs[index].PublicGoal = ""
			break
		}
	}
	if err := Validate(bundle); err == nil || !strings.Contains(err.Error(), "tracked public plan") {
		t.Fatalf("missing tracked public goal error = %v", err)
	}
}

func TestValidateRejectsInvalidStoryConsequence(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	arc := bundle.StoryArcs["qinglan_intel"]
	arc.ConsequenceRules[0].States = []string{"missing"}
	bundle.StoryArcs[arc.ID] = arc
	if err := Validate(bundle); err == nil || !strings.Contains(err.Error(), "unknown state") {
		t.Fatalf("invalid consequence state error = %v", err)
	}

	bundle, err = Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("reload bundle: %v", err)
	}
	arc = bundle.StoryArcs["qinglan_intel"]
	arc.ConsequenceRules[1].RelationMetric = "influence"
	bundle.StoryArcs[arc.ID] = arc
	if err := Validate(bundle); err == nil || !strings.Contains(err.Error(), "relation interpolation") {
		t.Fatalf("invalid consequence interpolation error = %v", err)
	}
}

func TestValidateRejectsIncompleteStoryFeedback(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	arc := bundle.StoryArcs["qinglan_intel"]
	arc.Nodes[0].Choices[0].Feedback.Messages = nil
	bundle.StoryArcs[arc.ID] = arc
	if err := Validate(bundle); err == nil || !strings.Contains(err.Error(), "feedback requires") {
		t.Fatalf("incomplete story feedback error = %v", err)
	}

	bundle, err = Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("reload bundle: %v", err)
	}
	arc = bundle.StoryArcs["qinglan_intel"]
	arc.Nodes[0].Choices[0].Feedback.Presentation.Subject = "hidden_actor"
	bundle.StoryArcs[arc.ID] = arc
	if err := Validate(bundle); err == nil || !strings.Contains(err.Error(), "presentation subject") {
		t.Fatalf("invalid story presentation error = %v", err)
	}
}

func TestValidateRejectsInvalidContestContentRule(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	bundle.Scenario.Contest.OutcomeRules[0].WinnerID = "missing"
	if err := Validate(bundle); err == nil || !strings.Contains(err.Error(), "outcome rule") {
		t.Fatalf("invalid contest rule error = %v", err)
	}
}

func TestValidateRejectsUndeclaredFlag(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	delete(bundle.Flags, "world:valley_open")
	if err := Validate(bundle); err == nil || !strings.Contains(err.Error(), "world:valley_open") {
		t.Fatalf("undeclared flag error = %v", err)
	}
}

func TestValidateRejectsUnknownEffectType(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	bundle.Scenario.FixedEvents[0].Effects[0].Type = domain.EffectType("typo_effect")
	if err := Validate(bundle); err == nil || !strings.Contains(err.Error(), "unknown effect type") {
		t.Fatalf("unknown effect error = %v", err)
	}
}

func TestValidateRejectsUnknownConditionTypeAndInvalidFields(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	bundle.NPCs[0].Strategies[0].Conditions = append(bundle.NPCs[0].Strategies[0].Conditions, domain.Condition{Type: "script"})
	if err := Validate(bundle); err == nil || !strings.Contains(err.Error(), "unknown condition type") {
		t.Fatalf("unknown condition error = %v", err)
	}

	bundle, err = Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatalf("reload bundle: %v", err)
	}
	bundle.NPCs[0].Strategies[0].Conditions = append(bundle.NPCs[0].Strategies[0].Conditions, domain.Condition{Type: domain.ConditionHasItem, Key: "antidote", Value: "unexpected"})
	if err := Validate(bundle); err == nil || !strings.Contains(err.Error(), "invalid item or fields") {
		t.Fatalf("invalid condition fields error = %v", err)
	}
}

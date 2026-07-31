package batch

import (
	"bytes"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"fantu/internal/domain"
	"fantu/internal/scenario"
)

func loadInputs(t *testing.T) (string, string) {
	t.Helper()
	return filepath.Join("..", "..", "data", "blackwind"), filepath.Join("..", "..", "testdata")
}

func TestInvestigationEfficacyRequiresLaterTriggeredAction(t *testing.T) {
	events := []domain.WorldEvent{
		{ID: "E1", Type: "action", ActionID: "verify"},
		{ID: "E2", Type: "action", ActionID: "verify"},
		{ID: "E3", Type: "action", TriggerEventIDs: []string{"E1"}},
	}
	total, useful := investigationEfficacy(events)
	if total != 2 || useful != 1 {
		t.Fatalf("investigation efficacy = %d/%d, want 1/2", useful, total)
	}
}

func TestFailureDiversityCountsFirstLaterActionPerActor(t *testing.T) {
	events := []domain.WorldEvent{
		{ID: "E1", ActorID: "N01", Type: "action_failed"},
		{ID: "E2", ActorID: "N02", Type: "action", ActionID: "buy"},
		{ID: "E3", ActorID: "N01", Type: "action_start", ActionID: "heal"},
		{ID: "E4", ActorID: "N03", Type: "action_interrupted"},
	}
	total, followUps := failureDiversity(events)
	if total != 2 || followUps["heal"] != 1 || followUps["none"] != 1 {
		t.Fatalf("failure diversity total=%d followups=%v", total, followUps)
	}
}

func TestOutcomeEntropyIdleAndRepeatMetrics(t *testing.T) {
	if got := ownerEntropy(map[string]int{"A": 1, "B": 1}); got != 1 {
		t.Fatalf("balanced binary entropy = %f, want 1", got)
	}
	decisions := []domain.DecisionRecord{
		{ActorID: "N01", Choices: []domain.RankedChoice{{ActionID: "buy"}}},
		{ActorID: "N01", Choices: []domain.RankedChoice{{ActionID: "buy"}}},
		{ActorID: "N01", Choices: []domain.RankedChoice{{ActionID: "heal"}}},
	}
	transitions, repeats := decisionRepetition(decisions)
	if transitions != 2 || repeats != 1 {
		t.Fatalf("repetition = %d/%d, want 1/2", repeats, transitions)
	}
}

func TestBeliefPerturbationIsReproducibleAndChangesCognition(t *testing.T) {
	dataDir, plansDir := loadInputs(t)
	bundle, err := scenario.Load(dataDir)
	if err != nil {
		t.Fatalf("load bundle: %v", err)
	}
	plans, err := LoadPlans(plansDir, bundle)
	if err != nil {
		t.Fatalf("load plans: %v", err)
	}
	cfg := SweepConfig{BeliefDelta: 1}
	firstBundle, firstPlans := perturbInputs(bundle, plans, cfg, 42)
	secondBundle, secondPlans := perturbInputs(bundle, plans, cfg, 42)
	if !reflect.DeepEqual(firstBundle, secondBundle) || !reflect.DeepEqual(firstPlans, secondPlans) {
		t.Fatal("same seed produced different cognition variants")
	}
	changed := false
	for i := range bundle.NPCs {
		if !reflect.DeepEqual(bundle.NPCs[i].Beliefs, firstBundle.NPCs[i].Beliefs) {
			changed = true
			break
		}
	}
	if !changed {
		t.Fatal("belief perturbation changed no belief presence, confidence, or source")
	}
	if reflect.DeepEqual(bundle.NPCs, firstBundle.NPCs) {
		t.Fatal("test setup did not produce an input variant")
	}
}

func TestWorldPerturbationIsDeepCopiedAndReproducible(t *testing.T) {
	dataDir, plansDir := loadInputs(t)
	bundle, err := scenario.Load(dataDir)
	if err != nil {
		t.Fatalf("load bundle: %v", err)
	}
	plans, err := LoadPlans(plansDir, bundle)
	if err != nil {
		t.Fatalf("load plans: %v", err)
	}
	original := cloneBundle(bundle)
	first, _ := perturbInputs(bundle, plans, SweepConfig{WorldDelta: 1}, 17)
	second, _ := perturbInputs(bundle, plans, SweepConfig{WorldDelta: 1}, 17)
	if !reflect.DeepEqual(first, second) {
		t.Fatal("same seed produced different world variants")
	}
	if reflect.DeepEqual(original.Items, first.Items) && reflect.DeepEqual(original.Locations, first.Locations) && reflect.DeepEqual(original.Scenario.Markets, first.Scenario.Markets) {
		t.Fatal("world perturbation changed no item owner, route, or stock")
	}
	if !reflect.DeepEqual(bundle.Items, original.Items) || !reflect.DeepEqual(bundle.Locations, original.Locations) || !reflect.DeepEqual(bundle.Scenario.Markets, original.Scenario.Markets) {
		t.Fatal("world perturbation mutated source items, routes, or markets")
	}
	for i := range bundle.NPCs {
		if strings.Join(bundle.NPCs[i].Items, "\x00") != strings.Join(original.NPCs[i].Items, "\x00") {
			t.Fatalf("world perturbation mutated source NPC %s inventory: source=%v original=%v", bundle.NPCs[i].ID, bundle.NPCs[i].Items, original.NPCs[i].Items)
		}
	}
	for itemID, item := range first.Items {
		if !item.Unique {
			continue
		}
		count := 0
		for _, npc := range first.NPCs {
			for _, held := range npc.Items {
				if held == itemID {
					count++
				}
			}
		}
		if _, npcOwner := firstNPC(first.NPCs, item.Owner); npcOwner && count != 1 {
			t.Fatalf("relocated unique item %s inventory count = %d", itemID, count)
		}
	}
}

func firstNPC(npcs []domain.NPCConfig, id string) (domain.NPCConfig, bool) {
	for _, npc := range npcs {
		if npc.ID == id {
			return npc, true
		}
	}
	return domain.NPCConfig{}, false
}

func TestBatchRunsAllAcceptanceScenarios(t *testing.T) {
	dataDir, plansDir := loadInputs(t)
	bundle, err := scenario.Load(dataDir)
	if err != nil {
		t.Fatalf("load bundle: %v", err)
	}
	plans, err := LoadPlans(plansDir, bundle)
	if err != nil {
		t.Fatalf("load plans: %v", err)
	}
	summary, err := Run(bundle, plans, true)
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if got, want := len(summary.Results), 8; got != want {
		t.Fatalf("run count = %d, want %d", got, want)
	}
	if got, want := len(summary.OwnerDistribution), 5; got != want {
		t.Fatalf("owner count = %d, want %d", got, want)
	}
	if got := summary.OwnerDistribution["李玄"]; got != 3 {
		t.Fatalf("Li Xuan outcome count = %d, want 3", got)
	}
	if len(summary.ActionDistribution) == 0 {
		t.Fatal("action distribution is empty")
	}
	if _, ok := summary.ResourceFlow["spirit_stones"]; !ok {
		t.Fatal("resource flow does not include spirit stones")
	}
	if got, want := len(summary.Warnings), 0; got != want {
		t.Fatalf("warning count = %d, want %d: %v", got, want, summary.Warnings)
	}
	if summary.ActionDistribution["cultivate"] == 0 {
		t.Fatal("generic planner did not cover cultivate")
	}
	if summary.RuleCoverage["condition:belief"] == 0 || summary.RuleCoverage["effect:set_flag"] == 0 {
		t.Fatalf("rule coverage missing core condition/effect: %v", summary.RuleCoverage)
	}
}

func TestBatchIsDeterministic(t *testing.T) {
	dataDir, plansDir := loadInputs(t)
	bundle, err := scenario.Load(dataDir)
	if err != nil {
		t.Fatalf("load bundle: %v", err)
	}
	plans, err := LoadPlans(plansDir, bundle)
	if err != nil {
		t.Fatalf("load plans: %v", err)
	}
	first, err := Run(bundle, plans, true)
	if err != nil {
		t.Fatalf("first run: %v", err)
	}
	second, err := Run(bundle, plans, true)
	if err != nil {
		t.Fatalf("second run: %v", err)
	}
	if !reflect.DeepEqual(first, second) {
		t.Fatal("batch output is not deterministic")
	}
}

func TestMarkdownContainsDistributions(t *testing.T) {
	summary := Summary{
		Results:            []Result{{RunID: "T00", OwnerName: "李玄", Outcome: "baseline"}},
		OwnerDistribution:  map[string]int{"李玄": 1},
		ActionDistribution: map[string]int{"explore": 2},
		ResourceFlow:       map[string]int{"spirit_stones": -20},
	}
	var output bytes.Buffer
	if err := Markdown(&output, summary); err != nil {
		t.Fatalf("Markdown() error = %v", err)
	}
	for _, expected := range []string{"归属分布", "行动分布", "规则覆盖矩阵", "资源净流", "李玄", "explore"} {
		if !strings.Contains(output.String(), expected) {
			t.Fatalf("report does not contain %q", expected)
		}
	}
}

func TestSweepIsReproducibleAndDoesNotMutateInputs(t *testing.T) {
	dataDir, plansDir := loadInputs(t)
	bundle, err := scenario.Load(dataDir)
	if err != nil {
		t.Fatalf("load bundle: %v", err)
	}
	plans, err := LoadPlans(plansDir, bundle)
	if err != nil {
		t.Fatalf("load plans: %v", err)
	}
	originalBundle, err := scenario.Load(dataDir)
	if err != nil {
		t.Fatalf("reload bundle: %v", err)
	}
	originalPlans, err := LoadPlans(plansDir, originalBundle)
	if err != nil {
		t.Fatalf("reload plans: %v", err)
	}
	cfg := SweepConfig{Seeds: []int64{7, 8, 9}, ResourceDelta: 1, RelationshipDelta: 2, CostDelta: 1}

	first, err := RunSweep(bundle, plans, true, cfg)
	if err != nil {
		t.Fatalf("first sweep: %v", err)
	}
	second, err := RunSweep(bundle, plans, true, cfg)
	if err != nil {
		t.Fatalf("second sweep: %v", err)
	}
	if !reflect.DeepEqual(first, second) {
		t.Fatal("parameter sweep is not reproducible")
	}
	if got, want := len(first.Results), 24; got != want {
		t.Fatalf("sweep run count = %d, want %d", got, want)
	}
	if first.Sweep == nil || len(first.Sweep.Seeds) != 3 {
		t.Fatalf("missing sweep metadata: %#v", first.Sweep)
	}
	if !reflect.DeepEqual(bundle, originalBundle) {
		t.Fatal("parameter sweep mutated its source bundle")
	}
	if !reflect.DeepEqual(plans, originalPlans) {
		t.Fatal("parameter sweep mutated its source plans")
	}
	for _, result := range first.Results {
		if !result.Swept || result.BaseRunID == "" || result.Seed == 0 {
			t.Fatalf("incomplete sweep identity: %#v", result)
		}
	}
}

func TestPerturbationCreatesBoundedDirectionalRelations(t *testing.T) {
	dataDir, plansDir := loadInputs(t)
	bundle, err := scenario.Load(dataDir)
	if err != nil {
		t.Fatalf("load bundle: %v", err)
	}
	plans, err := LoadPlans(plansDir, bundle)
	if err != nil {
		t.Fatalf("load plans: %v", err)
	}
	variant, _ := perturbInputs(bundle, plans, SweepConfig{ResourceDelta: 2, RelationshipDelta: 3, CostDelta: 2}, 42)
	if len(variant.InitialRelations) == 0 {
		t.Fatal("relationship perturbation created no directional edges")
	}
	for _, relation := range variant.InitialRelations {
		if relation.From == "" || relation.To == "" {
			t.Fatalf("invalid relation edge: %#v", relation)
		}
		if relation.Trust < 0 || relation.Trust > 3 || relation.Suspicion < 0 || relation.Suspicion > 3 {
			t.Fatalf("relation outside configured bounds: %#v", relation)
		}
	}
}

func TestSweepMarkdownShowsScenarioStability(t *testing.T) {
	summary := Summary{
		Results: []Result{
			{RunID: "T00/S1", BaseRunID: "T00", OwnerName: "李玄", Swept: true, Seed: 1},
			{RunID: "T00/S2", BaseRunID: "T00", OwnerName: "沈砚秋", Swept: true, Seed: 2},
		},
		OwnerDistribution:  map[string]int{"李玄": 1, "沈砚秋": 1},
		ActionDistribution: map[string]int{}, ResourceFlow: map[string]int{},
		Sweep: &SweepInfo{Seeds: []int64{1, 2}, ResourceDelta: 2, RelationshipDelta: 2, CostDelta: 1},
	}
	var output bytes.Buffer
	if err := Markdown(&output, summary); err != nil {
		t.Fatalf("Markdown() error = %v", err)
	}
	for _, expected := range []string{"参数扫描", "场景稳定性", "T00", "50.0%"} {
		if !strings.Contains(output.String(), expected) {
			t.Fatalf("sweep report does not contain %q", expected)
		}
	}
}

func TestSweepRejectsInvalidConfiguration(t *testing.T) {
	if _, err := RunSweep(domain.Bundle{}, nil, false, SweepConfig{}); err == nil {
		t.Fatal("empty seed list should fail")
	}
	if _, err := RunSweep(domain.Bundle{}, nil, false, SweepConfig{Seeds: []int64{1}, RelationshipDelta: 6}); err == nil {
		t.Fatal("out-of-range relationship delta should fail")
	}
}

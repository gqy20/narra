package scenario

import (
	"path/filepath"
	"testing"

	"fantu/internal/domain"
)

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
	for _, npc := range bundle.NPCs {
		if npc.PublicProfile == "" || npc.PublicRole == "" || len(npc.PublicInterests) == 0 || npc.PublicRisk == "" {
			t.Fatalf("NPC %s lacks complete public decision context", npc.ID)
		}
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

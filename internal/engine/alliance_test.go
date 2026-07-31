package engine

import (
	"testing"

	"fantu/internal/domain"
)

func TestAllianceRequiresCommonGoalTrustAndBenefitShares(t *testing.T) {
	simulation := New(loadBlackwind(t))
	simulation.state.Relations[domain.RelationKey("N01", "N03")] = domain.Relation{From: "N01", To: "N03", Trust: 3}
	simulation.state.Relations[domain.RelationKey("N03", "N01")] = domain.Relation{From: "N03", To: "N01", Trust: 3}
	request := domain.AllianceRequest{
		ID: "A1", Members: []string{"N03", "N01"}, GoalType: "acquire", TargetID: "qingsuizhi", MinTrust: 2,
		BenefitShares: map[string]int{"N01": 60, "N03": 40},
	}
	state, err := simulation.FormAlliance(request)
	if err != nil {
		t.Fatalf("FormAlliance() error = %v", err)
	}
	alliance := state.Alliances["A1"]
	if alliance.Status != "active" || alliance.BenefitShares["N01"] != 60 || alliance.Members[0] != "N01" {
		t.Fatalf("alliance = %+v", alliance)
	}
}

func TestAllianceRejectsInsufficientTrust(t *testing.T) {
	simulation := New(loadBlackwind(t))
	_, err := simulation.FormAlliance(domain.AllianceRequest{
		ID: "A1", Members: []string{"N01", "N03"}, GoalType: "acquire", TargetID: "qingsuizhi", MinTrust: 1,
		BenefitShares: map[string]int{"N01": 50, "N03": 50},
	})
	if err == nil {
		t.Fatal("FormAlliance() accepted insufficient mutual trust")
	}
}

func TestAllianceBetrayalChangesStatusAndRelations(t *testing.T) {
	simulation := New(loadBlackwind(t))
	simulation.state.Relations[domain.RelationKey("N01", "N03")] = domain.Relation{From: "N01", To: "N03", Trust: 3}
	simulation.state.Relations[domain.RelationKey("N03", "N01")] = domain.Relation{From: "N03", To: "N01", Trust: 3}
	_, err := simulation.FormAlliance(domain.AllianceRequest{
		ID: "A1", Members: []string{"N01", "N03"}, GoalType: "acquire", TargetID: "qingsuizhi", MinTrust: 2,
		BenefitShares: map[string]int{"N01": 50, "N03": 50},
	})
	if err != nil {
		t.Fatalf("FormAlliance() error = %v", err)
	}
	state, err := simulation.BetrayAlliance("A1", "N01")
	if err != nil {
		t.Fatalf("BetrayAlliance() error = %v", err)
	}
	if state.Alliances["A1"].Status != "betrayed" || state.Alliances["A1"].BetrayerID != "N01" {
		t.Fatalf("betrayed alliance = %+v", state.Alliances["A1"])
	}
	relation := state.RelationBetween("N03", "N01")
	if relation.Trust != 0 || relation.Hatred != 2 {
		t.Fatalf("post-betrayal relation = %+v", relation)
	}
}

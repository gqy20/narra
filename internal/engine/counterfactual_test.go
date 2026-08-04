package engine

import (
	"testing"

	"narra/internal/domain"
)

func TestDecisionAuditMeasuresRelationshipAndInformationCounterfactuals(t *testing.T) {
	bundle := loadBlackwind(t)
	simulation := New(bundle)
	npc := simulation.state.NPCs["N03"]
	npc.Beliefs["F01"] = domain.Belief{FactID: "F01", Confidence: 3, SourceEventID: "E-source"}
	simulation.state.Relations[domain.RelationKey("N03", "N02")] = domain.Relation{From: "N03", To: "N02", Trust: 5}
	strategies := []domain.Strategy{
		{ID: "z-informed", ActionID: "inquire", TargetID: "N02", Conditions: []domain.Condition{{Type: "belief", Key: "F01", MinConfidence: 1}}},
		{ID: "a-fallback", ActionID: "inquire", TargetID: "N01"},
	}
	choices := simulation.rankChoices(simulation.state, npc, strategies)
	if len(choices) != 2 || choices[0].StrategyID != "z-informed" {
		t.Fatalf("actual choices = %+v, want relationship-backed informed strategy", choices)
	}
	record := domain.DecisionRecord{Choices: choices}
	simulation.auditDecision(simulation.state, npc.ID, strategies, choices[0].StrategyID, &record)
	if !record.RelationshipRelevant || !record.RelationshipChangedTop || record.WithoutRelationshipStrategyID != "a-fallback" {
		t.Fatalf("relationship audit = %+v", record)
	}
	if len(record.Counterfactuals) != 1 {
		t.Fatalf("counterfactuals = %+v, want one belief removal", record.Counterfactuals)
	}
	got := record.Counterfactuals[0]
	if !got.Changed || got.TriggerEventID != "E-source" || got.AlternativeStrategyID != "a-fallback" {
		t.Fatalf("belief counterfactual = %+v", got)
	}
}

package engine

import (
	"testing"

	"narra/internal/domain"
)

func debtTestEngine(t *testing.T) *Engine {
	t.Helper()
	bundle := loadBlackwind(t)
	bundle.Scenario.Duration = 2
	bundle.Scenario.FixedEvents = nil
	bundle.Scenario.Contest.Day = 3
	bundle.Scenario.Phases = []domain.SituationPhase{{ID: "test", Name: "测试", FromDay: 1, ToDay: 2}}
	bundle.NPCs = []domain.NPCConfig{
		{ID: "N01", Name: "债权人", Location: "L01", Resources: map[string]int{"spirit_stones": 100}},
		{ID: "N02", Name: "债务人", Location: "L01", Resources: map[string]int{"spirit_stones": 10}},
	}
	return New(bundle)
}

func TestDebtLifecycleSupportsPartialAndFullRepayment(t *testing.T) {
	simulation := debtTestEngine(t)
	state, err := simulation.CreateLoan(domain.LoanRequest{ID: "D1", CreditorID: "N01", DebtorID: "N02", Resource: "spirit_stones", Amount: 20, DueDay: 2})
	if err != nil {
		t.Fatalf("CreateLoan() error = %v", err)
	}
	if state.NPCs["N01"].Resources["spirit_stones"] != 80 || state.NPCs["N02"].Resources["spirit_stones"] != 30 {
		t.Fatal("loan did not transfer principal")
	}
	state, err = simulation.RepayDebt("D1", 5)
	if err != nil || state.Debts["D1"].Outstanding != 15 || state.Debts["D1"].Status != "active" {
		t.Fatalf("partial repayment state=%+v err=%v", state.Debts["D1"], err)
	}
	state, err = simulation.RepayDebt("D1", 15)
	if err != nil || state.Debts["D1"].Status != "paid" || state.Debts["D1"].SettledEventID == "" {
		t.Fatalf("full repayment state=%+v err=%v", state.Debts["D1"], err)
	}
	if state.NPCs["N01"].Resources["spirit_stones"] != 100 || state.NPCs["N02"].Resources["spirit_stones"] != 10 {
		t.Fatal("repayment did not restore balances")
	}
}

func TestDebtDefaultsAtDeadlineAndChangesCreditorRelation(t *testing.T) {
	simulation := debtTestEngine(t)
	if _, err := simulation.CreateLoan(domain.LoanRequest{ID: "D1", CreditorID: "N01", DebtorID: "N02", Resource: "spirit_stones", Amount: 20, DueDay: 1}); err != nil {
		t.Fatalf("CreateLoan() error = %v", err)
	}
	state, err := simulation.Step(nil)
	if err != nil {
		t.Fatalf("Step() error = %v", err)
	}
	if state.Debts["D1"].Status != "defaulted" {
		t.Fatalf("debt status = %s, want defaulted", state.Debts["D1"].Status)
	}
	relation := state.RelationBetween("N01", "N02")
	if relation.Trust != -2 || relation.Suspicion != 2 {
		t.Fatalf("default relation = %+v", relation)
	}
	if state.Events[len(state.Events)-1].Type != "debt_defaulted" {
		t.Fatal("default event missing")
	}
}

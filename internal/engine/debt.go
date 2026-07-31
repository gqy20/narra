package engine

import (
	"fmt"
	"sort"

	"fantu/internal/domain"
)

func (e *Engine) CreateLoan(request domain.LoanRequest) (*domain.WorldState, error) {
	if request.ID == "" || e.state.Debts[request.ID] != nil || request.CreditorID == request.DebtorID || !e.actorExists(request.CreditorID) || !e.actorExists(request.DebtorID) {
		return nil, fmt.Errorf("loan requires a unique id and two distinct known actors")
	}
	if request.Resource == "" || request.Amount <= 0 || request.DueDay <= e.state.Day {
		return nil, fmt.Errorf("loan requires positive amount and a future due day")
	}
	if e.actorResources(request.CreditorID)[request.Resource] < request.Amount {
		return nil, fmt.Errorf("creditor cannot fund loan")
	}
	event := e.newEvent("loan_created", request.CreditorID, request.DebtorID, fmt.Sprintf("借出 %s×%d，到期日 %d", request.Resource, request.Amount, request.DueDay), request.ID, nil)
	e.actorResources(request.CreditorID)[request.Resource] -= request.Amount
	e.actorResources(request.DebtorID)[request.Resource] += request.Amount
	e.state.Debts[request.ID] = &domain.Debt{
		ID: request.ID, CreditorID: request.CreditorID, DebtorID: request.DebtorID, Resource: request.Resource,
		Principal: request.Amount, Outstanding: request.Amount, DueDay: request.DueDay, Status: "active", CreatedEventID: event.ID,
	}
	e.state.Events = append(e.state.Events, event)
	return e.State(), nil
}

func (e *Engine) RepayDebt(debtID string, amount int) (*domain.WorldState, error) {
	debt := e.state.Debts[debtID]
	if debt == nil || debt.Status != "active" || amount <= 0 || amount > debt.Outstanding {
		return nil, fmt.Errorf("invalid repayment for debt %s", debtID)
	}
	if e.actorResources(debt.DebtorID)[debt.Resource] < amount {
		return nil, fmt.Errorf("debtor cannot repay %d %s", amount, debt.Resource)
	}
	event := e.newEvent("debt_repaid", debt.DebtorID, debt.CreditorID, fmt.Sprintf("偿还 %s×%d", debt.Resource, amount), debtID, nil)
	event.ParentEventID = debt.CreatedEventID
	e.actorResources(debt.DebtorID)[debt.Resource] -= amount
	e.actorResources(debt.CreditorID)[debt.Resource] += amount
	debt.Outstanding -= amount
	if debt.Outstanding == 0 {
		debt.Status = "paid"
		debt.SettledEventID = event.ID
	}
	e.state.Events = append(e.state.Events, event)
	return e.State(), nil
}

func (e *Engine) processDebtDeadlines(day int) {
	ids := make([]string, 0, len(e.state.Debts))
	for id := range e.state.Debts {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	for _, id := range ids {
		debt := e.state.Debts[id]
		if debt.Status != "active" || day < debt.DueDay || debt.Outstanding == 0 {
			continue
		}
		event := e.newEvent("debt_defaulted", debt.DebtorID, debt.CreditorID, fmt.Sprintf("债务到期违约：%s 尚欠 %d", id, debt.Outstanding), id, nil)
		event.ParentEventID = debt.CreatedEventID
		debt.Status = "defaulted"
		debt.SettledEventID = event.ID
		key := domain.RelationKey(debt.CreditorID, debt.DebtorID)
		relation := e.state.Relations[key]
		relation.From, relation.To = debt.CreditorID, debt.DebtorID
		relation.Trust = clampRelation(relation.Trust - 2)
		relation.Suspicion = clampRelation(relation.Suspicion + 2)
		e.state.Relations[key] = relation
		e.state.Events = append(e.state.Events, event)
	}
}

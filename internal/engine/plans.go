package engine

import (
	"fmt"

	"fantu/internal/domain"
)

func (e *Engine) attachPlan(actorID string, strategy *domain.Strategy) {
	contestRule := e.bundle.Rules.Navigation.Contest
	isPurchase := e.isGeneratedMarketPurchase(strategy.ID)
	if !strategy.Generated || !isPurchase && strategy.ActionID != contestRule.ActionID {
		return
	}
	npc := e.state.NPCs[actorID]
	if npc == nil || !wantsContest(npc, contestRule) {
		return
	}
	plan := npc.Plans[npc.ActivePlanID]
	if plan == nil || plan.Status != "active" {
		plan = &domain.PlanChain{
			ID: fmt.Sprintf("plan-%s-%02d-contest", actorID, e.state.Day), GoalType: "acquire",
			TargetID: e.bundle.Scenario.Contest.ItemID, CreatedDay: e.state.Day, Status: "active",
			Steps: []domain.PlanStep{{ID: "supply", Description: "取得必要补给", Status: "pending"}, {ID: "navigate", Description: "沿路线接近目标", Status: "pending"}, {ID: "enter", Description: "进入目标地点", Status: "pending"}},
		}
		npc.Plans[plan.ID] = plan
		npc.ActivePlanID = plan.ID
	}
	stepID := ""
	if isPurchase {
		stepID = "supply"
	} else {
		stepID = "navigate"
		for _, effect := range strategy.Effects {
			if effect.Type == "move" && effect.Value == e.bundle.Scenario.Contest.LocationID {
				stepID = "enter"
			}
		}
	}
	plan.CurrentStepID = stepID
	setPlanStepStatus(plan, stepID, "active")
	strategy.PlanID, strategy.PlanStepID = plan.ID, stepID
}

func (e *Engine) isGeneratedMarketPurchase(strategyID string) bool {
	for _, rule := range e.bundle.Rules.FallbackStrategies {
		if rule.Strategy.ID == strategyID && rule.MarketPurchase != nil {
			return true
		}
	}
	return false
}

func (e *Engine) completePlanStep(actorID, planID, stepID string) {
	if planID == "" {
		return
	}
	npc := e.state.NPCs[actorID]
	plan := npc.Plans[planID]
	if plan == nil {
		return
	}
	setPlanStepStatus(plan, stepID, "completed")
	if stepID == "enter" {
		plan.Status = "completed"
		plan.CurrentStepID = ""
		npc.ActivePlanID = ""
	}
}

func (e *Engine) failPlan(actorID, planID string) {
	if planID == "" {
		return
	}
	npc := e.state.NPCs[actorID]
	if npc == nil || npc.Plans[planID] == nil {
		return
	}
	plan := npc.Plans[planID]
	setPlanStepStatus(plan, plan.CurrentStepID, "failed")
	plan.Status = "failed"
	npc.ActivePlanID = ""
}

func setPlanStepStatus(plan *domain.PlanChain, stepID, status string) {
	for i := range plan.Steps {
		if plan.Steps[i].ID == stepID {
			plan.Steps[i].Status = status
			return
		}
	}
}

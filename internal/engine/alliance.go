package engine

import (
	"fmt"
	"sort"

	"narra/internal/domain"
)

func (e *Engine) FormAlliance(request domain.AllianceRequest) (*domain.WorldState, error) {
	if request.ID == "" || e.state.Alliances[request.ID] != nil || len(request.Members) < 2 || !validAllianceGoal(request.GoalType) {
		return nil, fmt.Errorf("alliance requires unique id, valid goal, and at least two members")
	}
	members := append([]string(nil), request.Members...)
	sort.Strings(members)
	total, seen := 0, make(map[string]bool)
	for _, member := range members {
		if seen[member] || !e.actorExists(member) || !e.actorHasGoal(member, request.GoalType, request.TargetID) || request.BenefitShares[member] <= 0 {
			return nil, fmt.Errorf("alliance member %s lacks common goal or valid share", member)
		}
		seen[member] = true
		total += request.BenefitShares[member]
	}
	if total != 100 {
		return nil, fmt.Errorf("alliance benefit shares must total 100")
	}
	for _, from := range members {
		for _, to := range members {
			if from != to && e.state.RelationBetween(from, to).Trust < request.MinTrust {
				return nil, fmt.Errorf("trust %s -> %s is below %d", from, to, request.MinTrust)
			}
		}
	}
	event := e.newEvent("alliance_formed", members[0], "", "形成共同目标联盟："+request.TargetID, request.ID, nil)
	alliance := &domain.Alliance{
		ID: request.ID, Members: members, GoalType: request.GoalType, TargetID: request.TargetID,
		BenefitShares: copyIntMap(request.BenefitShares), Status: "active", CreatedEventID: event.ID,
	}
	e.state.Alliances[request.ID] = alliance
	e.state.Events = append(e.state.Events, event)
	return e.State(), nil
}

func (e *Engine) BetrayAlliance(allianceID, actorID string) (*domain.WorldState, error) {
	alliance := e.state.Alliances[allianceID]
	if alliance == nil || alliance.Status != "active" || !allianceMember(alliance.Members, actorID) {
		return nil, fmt.Errorf("actor %s cannot betray alliance %s", actorID, allianceID)
	}
	event := e.newEvent("alliance_betrayed", actorID, "", "背叛联盟："+allianceID, allianceID, nil)
	event.ParentEventID = alliance.CreatedEventID
	alliance.Status, alliance.BetrayerID, alliance.BrokenEventID = "betrayed", actorID, event.ID
	for _, member := range alliance.Members {
		if member == actorID {
			continue
		}
		key := domain.RelationKey(member, actorID)
		relation := e.state.Relations[key]
		relation.From, relation.To = member, actorID
		relation.Trust = clampRelation(relation.Trust - 3)
		relation.Hatred = clampRelation(relation.Hatred + 2)
		e.state.Relations[key] = relation
	}
	e.state.Events = append(e.state.Events, event)
	return e.State(), nil
}

func allianceMember(members []string, actorID string) bool {
	for _, member := range members {
		if member == actorID {
			return true
		}
	}
	return false
}

func (e *Engine) actorHasGoal(actorID, goalType, targetID string) bool {
	npc := e.state.NPCs[actorID]
	if npc == nil {
		return false
	}
	for _, goal := range npc.Goals {
		if goal.Type == goalType && goal.TargetID == targetID {
			return true
		}
	}
	return false
}

func validAllianceGoal(goalType string) bool {
	return goalType == "acquire" || goalType == "protect" || goalType == "profit" || goalType == "status" || goalType == "avoid"
}

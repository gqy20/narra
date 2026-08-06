package app

import (
	"fmt"
	"sort"
	"strings"
)

func knowledgeGraph(view PlayerView) KnowledgeGraph {
	graph := KnowledgeGraph{
		Nodes: make([]KnowledgeNode, 0, len(view.KnownActors)+len(view.KnownFacts)+len(view.RecentEvents)+len(view.WorldMap.Locations)),
		Edges: make([]KnowledgeEdge, 0),
	}
	nodeIndex := make(map[string]int)
	actorByName := make(map[string]string)
	edgeKeys := make(map[string]bool)
	relevantLocations := map[string]bool{view.Location.ID: true}
	for _, actor := range view.KnownActors {
		if actor.Plan != nil {
			relevantLocations[actor.Plan.LocationID] = true
			relevantLocations[actor.Plan.DestinationID] = true
		}
	}
	for _, action := range view.AvailableActions {
		if action.Kind == "move" {
			relevantLocations[strings.TrimPrefix(action.ID, "move:")] = true
		}
	}

	addNode := func(node KnowledgeNode) {
		if node.ID == "" || node.Label == "" {
			return
		}
		if _, exists := nodeIndex[node.ID]; exists {
			return
		}
		nodeIndex[node.ID] = len(graph.Nodes)
		graph.Nodes = append(graph.Nodes, node)
	}
	addEdge := func(edge KnowledgeEdge) {
		if edge.SourceID == "" || edge.TargetID == "" || edge.SourceID == edge.TargetID {
			return
		}
		key := edge.SourceID + "\x00" + edge.TargetID + "\x00" + edge.Kind
		if edgeKeys[key] {
			return
		}
		edgeKeys[key] = true
		graph.Edges = append(graph.Edges, edge)
	}

	for _, location := range view.WorldMap.Locations {
		if !relevantLocations[location.ID] {
			continue
		}
		state := "可停留"
		if location.Current {
			state = "当前地点"
		} else if !location.Safe {
			state = "存在风险"
		}
		details := []KnowledgeDetail{}
		if location.Atmosphere != "" {
			details = append(details, KnowledgeDetail{Label: "环境", Value: location.Atmosphere})
		}
		addNode(KnowledgeNode{
			ID: "location:" + location.ID, Kind: "location", Label: location.Name,
			State: state, Summary: location.Description, Details: details,
		})
	}

	for _, actor := range view.KnownActors {
		details := make([]KnowledgeDetail, 0, 5)
		if actor.PublicRole != "" {
			details = append(details, KnowledgeDetail{Label: "身份", Value: actor.PublicRole})
		}
		if len(actor.PublicFocus) > 0 {
			details = append(details, KnowledgeDetail{Label: "关注", Value: strings.Join(actor.PublicFocus, "、")})
		}
		if actor.PublicRisk != "" {
			details = append(details, KnowledgeDetail{Label: "风险", Value: actor.PublicRisk})
		}
		state := actor.PublicRole
		if actor.Plan != nil {
			if actor.Plan.PublicGoal != "" {
				details = append(details, KnowledgeDetail{Label: "目标", Value: actor.Plan.PublicGoal})
			}
			if actor.Plan.Plan != "" {
				details = append(details, KnowledgeDetail{Label: "动向", Value: actor.Plan.Plan})
			}
			if actor.Plan.Status != "" {
				state = actor.Plan.Status
			}
		}
		nodeID := "actor:" + actor.ID
		actorByName[actor.Name] = nodeID
		addNode(KnowledgeNode{
			ID: nodeID, Kind: "actor", Label: actor.Name, State: state,
			Summary: actor.PublicProfile, Details: details,
		})
		if actor.Plan != nil && actor.Plan.LocationID != "" {
			addEdge(KnowledgeEdge{SourceID: nodeID, TargetID: "location:" + actor.Plan.LocationID, Kind: "located_at", Label: "位于"})
		}
	}

	for _, belief := range view.KnownFacts {
		state := "待核验"
		status := "unconfirmed"
		if belief.Contested {
			state = "存在冲突"
			status = "risk"
		} else if belief.Confidence >= 3 {
			state = "已核验"
			status = "confirmed"
		} else if belief.Confidence == 2 {
			state = "较可信"
		}
		nodeID := "claim:" + belief.FactID
		addNode(KnowledgeNode{
			ID: nodeID, Kind: "claim", Label: belief.Claim, State: state,
			Details: []KnowledgeDetail{
				{Label: "来源", Value: belief.Source},
				{Label: "获知时间", Value: fmt.Sprintf("第%d日", belief.LearnedOn+1)},
			},
		})
		if sourceID, ok := actorByName[belief.Source]; ok {
			addEdge(KnowledgeEdge{SourceID: sourceID, TargetID: nodeID, Kind: "source", Label: "提供", Status: status})
		}
	}

	for index, event := range view.RecentEvents {
		eventID := fmt.Sprintf("event:%d:%d", event.Day, index)
		addNode(KnowledgeNode{
			ID: eventID, Kind: "event", Label: event.Description, State: fmt.Sprintf("第%d日", event.Day+1),
		})
		if actorID, ok := actorByName[event.ActorName]; ok {
			addEdge(KnowledgeEdge{SourceID: actorID, TargetID: eventID, Kind: "involved", Label: "涉及"})
		}
	}

	for _, thread := range view.CausalThreads {
		actorID, actorOK := actorByName[thread.ActorName]
		factID := "claim:" + thread.FactID
		if actorOK {
			if _, factOK := nodeIndex[factID]; factOK {
				addEdge(KnowledgeEdge{SourceID: factID, TargetID: actorID, Kind: "influences", Label: "影响", Status: "confirmed"})
			}
		}
	}

	for _, route := range view.WorldMap.Routes {
		fromID := "location:" + route.FromID
		toID := "location:" + route.ToID
		_, fromOK := nodeIndex[fromID]
		_, toOK := nodeIndex[toID]
		if fromOK && toOK {
			status := "normal"
			if route.Status == "blocked" {
				status = "risk"
			} else if route.Status == "available" {
				status = "focus"
			}
			addEdge(KnowledgeEdge{SourceID: fromID, TargetID: toID, Kind: "route", Label: "通路", Status: status})
		}
	}

	for _, action := range view.AvailableActions {
		if action.FactID != "" && action.TargetID != "" {
			factID := "claim:" + action.FactID
			actorID := "actor:" + action.TargetID
			_, factOK := nodeIndex[factID]
			_, actorOK := nodeIndex[actorID]
			if factOK && actorOK {
				addEdge(KnowledgeEdge{SourceID: factID, TargetID: actorID, Kind: "available_action", Label: "可告知", Status: "focus"})
			}
		}
		var nodeID string
		if action.FactID != "" {
			nodeID = "claim:" + action.FactID
		} else if action.TargetID != "" {
			nodeID = "actor:" + action.TargetID
		} else if action.Kind == "move" {
			nodeID = "location:" + strings.TrimPrefix(action.ID, "move:")
		}
		if index, ok := nodeIndex[nodeID]; ok {
			graph.Nodes[index].ActionIDs = append(graph.Nodes[index].ActionIDs, action.ID)
		}
	}

	sort.SliceStable(graph.Nodes, func(i, j int) bool {
		if graph.Nodes[i].Kind == graph.Nodes[j].Kind {
			return graph.Nodes[i].Label < graph.Nodes[j].Label
		}
		return knowledgeKindOrder(graph.Nodes[i].Kind) < knowledgeKindOrder(graph.Nodes[j].Kind)
	})
	sort.SliceStable(graph.Edges, func(i, j int) bool {
		left := graph.Edges[i].SourceID + "\x00" + graph.Edges[i].TargetID + "\x00" + graph.Edges[i].Kind
		right := graph.Edges[j].SourceID + "\x00" + graph.Edges[j].TargetID + "\x00" + graph.Edges[j].Kind
		return left < right
	})
	return graph
}

func knowledgeKindOrder(kind string) int {
	switch kind {
	case "actor":
		return 0
	case "claim":
		return 1
	case "event":
		return 2
	case "location":
		return 3
	default:
		return 4
	}
}

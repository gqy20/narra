package app

import (
	"strings"
	"testing"

	"narra/internal/scenario"
)

func TestKnowledgeGraphOnlyProjectsVisiblePlayerInformation(t *testing.T) {
	view := testSession(t).View()
	graph := view.KnowledgeGraph
	if len(graph.Nodes) == 0 || len(graph.Edges) == 0 {
		t.Fatalf("knowledge graph is empty: %+v", graph)
	}

	nodes := make(map[string]KnowledgeNode, len(graph.Nodes))
	claimCount := 0
	for _, node := range graph.Nodes {
		nodes[node.ID] = node
		for _, detail := range node.Details {
			if strings.HasPrefix(detail.Value, "FCT_") {
				t.Fatalf("knowledge graph exposed an internal faction id: %+v", node)
			}
		}
		if node.Kind == "claim" {
			claimCount++
			if node.ID != "claim:F02" {
				t.Fatalf("knowledge graph exposed an unknown fact: %+v", node)
			}
		}
	}
	if claimCount != len(view.KnownFacts) {
		t.Fatalf("claim nodes = %d, known facts = %d", claimCount, len(view.KnownFacts))
	}
	claim := nodes["claim:F02"]
	if claim.Summary != "" {
		t.Fatalf("claim repeats a generic system disclaimer: %+v", claim)
	}
	if len(claim.ActionIDs) == 0 || claim.ActionIDs[0] != "verify:F02" {
		t.Fatalf("known claim did not expose its available action: %+v", claim)
	}
	for _, edge := range graph.Edges {
		if _, ok := nodes[edge.SourceID]; !ok {
			t.Fatalf("edge references missing source node: %+v", edge)
		}
		if _, ok := nodes[edge.TargetID]; !ok {
			t.Fatalf("edge references missing target node: %+v", edge)
		}
	}
}

func TestKnowledgeGraphWorksAcrossOfficialContentPacks(t *testing.T) {
	for _, world := range []string{"blackwind", "tianqi"} {
		t.Run(world, func(t *testing.T) {
			bundle, err := scenario.Load("../../data/" + world)
			if err != nil {
				t.Fatal(err)
			}
			session, err := NewSession(bundle, DefaultPlayer(bundle, "图谱测试者"))
			if err != nil {
				t.Fatal(err)
			}
			graph := session.View().KnowledgeGraph
			if len(graph.Nodes) == 0 {
				t.Fatalf("%s produced no visible graph nodes", world)
			}
			for _, node := range graph.Nodes {
				if node.Label == "" || node.Kind == "" {
					t.Fatalf("%s produced an invalid graph node: %+v", world, node)
				}
			}
		})
	}
}

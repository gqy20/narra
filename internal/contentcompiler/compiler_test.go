package contentcompiler

import (
	"path/filepath"
	"strings"
	"testing"

	"fantu/internal/domain"
	"fantu/internal/scenario"
)

func TestOfficialPackagesHaveNoCompilerErrors(t *testing.T) {
	root := filepath.Join("..", "..")
	for _, name := range []string{"blackwind", "tianqi", "orbital"} {
		t.Run(name, func(t *testing.T) {
			dir := filepath.Join(root, "data", name)
			bundle, err := scenario.Load(dir)
			if err != nil {
				t.Fatal(err)
			}
			report := Analyze(bundle, dir, root)
			if HasErrors(report) {
				t.Fatalf("compiler errors: %+v", report.Diagnostics)
			}
		})
	}
}

func TestArcAnalysisFindsUnreachableAndDeadEndStates(t *testing.T) {
	arc := domain.StoryArc{ID: "route", Title: "Route", InitialState: "start", States: []string{"start", "reachable", "orphan"}, Nodes: []domain.StoryNode{{ID: "go", FromState: "start", Choices: []domain.StoryChoice{{ID: "choice", Name: "Go", ToState: "reachable"}}}}}
	diagnostics := analyzeArc(arc, "arcs.yml")
	joined := fmtDiagnostics(diagnostics)
	if !strings.Contains(joined, "unreachable-state") || !strings.Contains(joined, "dead-end-state") {
		t.Fatalf("diagnostics = %s", joined)
	}
}

func fmtDiagnostics(items []Diagnostic) string {
	var b strings.Builder
	for _, item := range items {
		b.WriteString(item.Code + ":" + item.Message + "\n")
	}
	return b.String()
}

// Package contentcompiler performs build-time analysis of scenario packages.
// It complements scenario.Validate with graph, reference, asset, and simulation
// coverage checks that are useful to content authors before starting the game.
package contentcompiler

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"narra/internal/app"
	"narra/internal/domain"
	"narra/internal/scenario"
)

type Diagnostic struct {
	Severity string `json:"severity"`
	Code     string `json:"code"`
	File     string `json:"file,omitempty"`
	Line     int    `json:"line,omitempty"`
	Message  string `json:"message"`
}

type Analysis struct {
	ScenarioID  string       `json:"scenario_id"`
	Files       int          `json:"files"`
	Arcs        int          `json:"arcs"`
	Nodes       int          `json:"nodes"`
	Choices     int          `json:"choices"`
	Actions     int          `json:"actions"`
	Flags       int          `json:"flags"`
	Facts       int          `json:"facts"`
	Locations   int          `json:"locations"`
	Actors      int          `json:"actors"`
	Diagnostics []Diagnostic `json:"diagnostics"`
}

type Coverage struct {
	ScenarioID      string         `json:"scenario_id"`
	Runs            int            `json:"runs"`
	CompletedRuns   int            `json:"completed_runs"`
	ActionHits      map[string]int `json:"action_hits"`
	ChoiceHits      map[string]int `json:"choice_hits"`
	EndingHits      map[string]int `json:"ending_hits"`
	RejectedActions map[string]int `json:"rejected_action_hits,omitempty"`
	ActionCoverage  float64        `json:"action_coverage"`
	ChoiceCoverage  float64        `json:"choice_coverage"`
}

func LoadAndAnalyze(dir, repositoryRoot string) (domain.Bundle, Analysis, error) {
	bundle, err := scenario.Load(dir)
	if err != nil {
		return domain.Bundle{}, Analysis{}, err
	}
	report := Analyze(bundle, dir, repositoryRoot)
	return bundle, report, nil
}

func Analyze(bundle domain.Bundle, dir, repositoryRoot string) Analysis {
	report := Analysis{
		ScenarioID: bundle.Scenario.ID, Arcs: len(bundle.StoryArcs), Actions: len(bundle.Actions),
		Flags: len(bundle.Flags), Facts: len(bundle.Facts), Locations: len(bundle.Locations), Actors: len(bundle.NPCs),
	}
	if entries, err := os.ReadDir(dir); err == nil {
		for _, entry := range entries {
			if !entry.IsDir() {
				report.Files++
			}
		}
	}
	for _, arc := range bundle.StoryArcs {
		report.Nodes += len(arc.Nodes)
		for _, node := range arc.Nodes {
			report.Choices += len(node.Choices)
		}
		report.Diagnostics = append(report.Diagnostics, analyzeArc(arc, filepath.Join(dir, "arcs.yml"))...)
	}
	report.Diagnostics = append(report.Diagnostics, analyzeFlags(bundle, filepath.Join(dir, "flags.yml"))...)
	report.Diagnostics = append(report.Diagnostics, analyzeAssets(bundle, repositoryRoot, filepath.Join(dir, "presentation.yml"))...)
	sort.Slice(report.Diagnostics, func(i, j int) bool {
		if report.Diagnostics[i].Severity != report.Diagnostics[j].Severity {
			return report.Diagnostics[i].Severity < report.Diagnostics[j].Severity
		}
		if report.Diagnostics[i].File != report.Diagnostics[j].File {
			return report.Diagnostics[i].File < report.Diagnostics[j].File
		}
		return report.Diagnostics[i].Message < report.Diagnostics[j].Message
	})
	return report
}

func analyzeArc(arc domain.StoryArc, file string) []Diagnostic {
	reachable := map[string]bool{arc.InitialState: true}
	changed := true
	for changed {
		changed = false
		for _, node := range arc.Nodes {
			if !reachable[node.FromState] {
				continue
			}
			for _, choice := range node.Choices {
				if !reachable[choice.ToState] {
					reachable[choice.ToState] = true
					changed = true
				}
			}
		}
	}
	var result []Diagnostic
	outgoing := make(map[string]int)
	for _, node := range arc.Nodes {
		outgoing[node.FromState] += len(node.Choices)
		if !reachable[node.FromState] {
			item := diagnostic("error", "unreachable-node", file, fmt.Sprintf("arc %s node %s starts from unreachable state %s", arc.ID, node.ID, node.FromState))
			item.Line = findLine(file, "id: "+node.ID)
			result = append(result, item)
		}
		if node.FromDay > 0 && node.UntilDay > 0 && node.FromDay > node.UntilDay {
			item := diagnostic("error", "contradictory-window", file, fmt.Sprintf("arc %s node %s has from_day %d after until_day %d", arc.ID, node.ID, node.FromDay, node.UntilDay))
			item.Line = findLine(file, "id: "+node.ID)
			result = append(result, item)
		}
	}
	for _, state := range arc.States {
		if !reachable[state] {
			item := diagnostic("error", "unreachable-state", file, fmt.Sprintf("arc %s state %s is unreachable", arc.ID, state))
			item.Line = findLine(file, "states:")
			result = append(result, item)
		} else if outgoing[state] == 0 && !terminalState(arc, state) {
			item := diagnostic("warning", "dead-end-state", file, fmt.Sprintf("arc %s reachable state %s has no outgoing node and no consequence rule", arc.ID, state))
			item.Line = findLine(file, "states:")
			result = append(result, item)
		}
	}
	return result
}

func terminalState(arc domain.StoryArc, state string) bool {
	for _, rule := range arc.ConsequenceRules {
		for _, candidate := range rule.States {
			if candidate == state {
				return true
			}
		}
	}
	return false
}

func analyzeFlags(bundle domain.Bundle, file string) []Diagnostic {
	// Search the authored source instead of duplicating every place a flag can
	// occur in the domain model. This also covers route gates, contest rules,
	// generated strategies, and newly added declarative systems automatically.
	var authored strings.Builder
	dir := filepath.Dir(file)
	entries, _ := os.ReadDir(dir)
	for _, entry := range entries {
		if entry.IsDir() || strings.EqualFold(entry.Name(), filepath.Base(file)) {
			continue
		}
		ext := strings.ToLower(filepath.Ext(entry.Name()))
		if ext != ".yml" && ext != ".yaml" && ext != ".json" {
			continue
		}
		data, err := os.ReadFile(filepath.Join(dir, entry.Name()))
		if err == nil {
			authored.Write(data)
			authored.WriteByte('\n')
		}
	}
	source := authored.String()
	var result []Diagnostic
	for key, definition := range bundle.Flags {
		pattern := regexp.MustCompile(`(^|[^A-Za-z0-9_])` + regexp.QuoteMeta(definition.ID) + `([^A-Za-z0-9_]|$)`)
		if !pattern.MatchString(source) {
			item := diagnostic("warning", "unused-flag", file, fmt.Sprintf("declared flag %s:%s is never read or written", definition.Scope, definition.ID))
			item.Line = findLine(file, "id: "+definition.ID)
			result = append(result, item)
		}
		_ = key
	}
	return result
}

func analyzeAssets(bundle domain.Bundle, repositoryRoot, file string) []Diagnostic {
	if repositoryRoot == "" {
		return nil
	}
	var refs []string
	p := bundle.Presentation
	refs = append(refs, p.Terrain)
	for _, location := range p.Locations {
		refs = append(refs, location.Profile, location.Background)
	}
	for _, actor := range p.Actors {
		refs = append(refs, actor.Profile)
	}
	for _, value := range p.Events {
		refs = append(refs, value)
	}
	assetRoot := strings.TrimPrefix(strings.TrimSuffix(p.AssetRoot, "/"), "res://")
	if assetRoot != "" {
		if p.OpeningEvent != "" {
			refs = append(refs, "res://"+assetRoot+"/videos/events/"+p.OpeningEvent+".ogv")
		}
		if p.EndingEvent != "" {
			refs = append(refs, "res://"+assetRoot+"/videos/events/"+p.EndingEvent+".ogv")
		}
		if p.Audio.Music != "" && !strings.HasPrefix(p.Audio.Music, "res://") {
			name := strings.TrimSuffix(p.Audio.Music, ".ogg")
			refs = append(refs, "res://"+assetRoot+"/audio/music/"+name+".ogg")
		} else {
			refs = append(refs, p.Audio.Music)
		}
	}
	var result []Diagnostic
	for _, ref := range refs {
		if ref == "" || !strings.HasPrefix(ref, "res://") {
			continue
		}
		path := filepath.Join(repositoryRoot, "godot", filepath.FromSlash(strings.TrimPrefix(ref, "res://")))
		if _, err := os.Stat(path); os.IsNotExist(err) {
			item := diagnostic("error", "missing-asset", file, fmt.Sprintf("presentation asset does not exist: %s", ref))
			item.Line = findLine(file, ref)
			result = append(result, item)
		}
	}
	return result
}

func diagnostic(severity, code, file, message string) Diagnostic {
	return Diagnostic{Severity: severity, Code: code, File: filepath.ToSlash(file), Message: message}
}

func findLine(path, needle string) int {
	data, err := os.ReadFile(path)
	if err != nil {
		return 0
	}
	for index, line := range strings.Split(string(data), "\n") {
		if strings.Contains(line, needle) {
			return index + 1
		}
	}
	return 0
}

func HasErrors(report Analysis) bool {
	for _, item := range report.Diagnostics {
		if item.Severity == "error" {
			return true
		}
	}
	return false
}

func Mermaid(bundle domain.Bundle) string {
	var builder strings.Builder
	builder.WriteString("flowchart LR\n")
	arcIDs := make([]string, 0, len(bundle.StoryArcs))
	for id := range bundle.StoryArcs {
		arcIDs = append(arcIDs, id)
	}
	sort.Strings(arcIDs)
	for _, id := range arcIDs {
		arc := bundle.StoryArcs[id]
		for _, state := range arc.States {
			fmt.Fprintf(&builder, "  %s_%s[\"%s / %s\"]\n", safeID(id), safeID(state), arc.Title, state)
		}
		for _, node := range arc.Nodes {
			for _, choice := range node.Choices {
				fmt.Fprintf(&builder, "  %s_%s -->|\"%s\"| %s_%s\n", safeID(id), safeID(node.FromState), escape(choice.Name), safeID(id), safeID(choice.ToState))
			}
		}
	}
	return builder.String()
}

func safeID(value string) string {
	replacer := strings.NewReplacer("-", "_", ":", "_", ".", "_")
	return replacer.Replace(value)
}
func escape(value string) string { return strings.ReplaceAll(value, "\"", "'") }

func Simulate(bundle domain.Bundle, runs int, seed int64) (Coverage, error) {
	if runs <= 0 {
		return Coverage{}, fmt.Errorf("runs must be positive")
	}
	coverage := Coverage{ScenarioID: bundle.Scenario.ID, Runs: runs, ActionHits: map[string]int{}, ChoiceHits: map[string]int{}, EndingHits: map[string]int{}, RejectedActions: map[string]int{}}
	totalActions := map[string]bool{"wait": true}
	totalChoices := make(map[string]bool)
	for _, arc := range bundle.StoryArcs {
		for _, node := range arc.Nodes {
			for _, choice := range node.Choices {
				totalChoices[choice.ID] = true
			}
		}
	}
	for run := 0; run < runs; run++ {
		rng := rand.New(rand.NewSource(seed + int64(run)*7919))
		session, err := app.NewSession(bundle, bundle.DefaultPlayer)
		if err != nil {
			return coverage, err
		}
		for !session.View().Ended && !session.View().Resolved {
			view := session.View()
			options := view.AvailableActions
			for _, option := range options {
				totalActions[option.ID] = true
			}
			candidates := make([]string, 0, len(options)+1)
			for _, option := range options {
				candidates = append(candidates, option.ID)
			}
			candidates = append(candidates, "wait")
			rng.Shuffle(len(candidates), func(i, j int) { candidates[i], candidates[j] = candidates[j], candidates[i] })
			executed := false
			for _, choice := range candidates {
				if _, err := session.Execute(choice); err != nil {
					coverage.RejectedActions[choice]++
					continue
				}
				coverage.ActionHits[choice]++
				if totalChoices[choice] {
					coverage.ChoiceHits[choice]++
				}
				executed = true
				break
			}
			if !executed {
				return coverage, fmt.Errorf("run %d day %d: every available action was rejected", run+1, view.Day+1)
			}
		}
		view := session.View()
		if view.Ended || view.Resolved {
			coverage.CompletedRuns++
		}
		coverage.EndingHits[view.Outcome]++
	}
	coverage.ActionCoverage = ratio(len(coverage.ActionHits), len(totalActions))
	coveredChoices := 0
	for id := range totalChoices {
		if coverage.ChoiceHits[id] > 0 {
			coveredChoices++
		}
	}
	coverage.ChoiceCoverage = ratio(coveredChoices, len(totalChoices))
	return coverage, nil
}

func ratio(hit, total int) float64 {
	if total == 0 {
		return 1
	}
	return float64(hit) / float64(total)
}

func WriteJSON(value any) ([]byte, error) { return json.MarshalIndent(value, "", "  ") }

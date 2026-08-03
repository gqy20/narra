package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"

	"fantu/internal/contentcompiler"
)

func main() {
	if len(os.Args) < 3 {
		usage()
		os.Exit(2)
	}
	command, dataDir := os.Args[1], os.Args[2]
	repositoryRoot, _ := filepath.Abs(".")
	bundle, analysis, err := contentcompiler.LoadAndAnalyze(dataDir, repositoryRoot)
	if err != nil {
		fail(err)
	}
	switch command {
	case "validate":
		printAnalysis(analysis)
		if contentcompiler.HasErrors(analysis) {
			os.Exit(1)
		}
	case "test":
		printAnalysis(analysis)
		if contentcompiler.HasErrors(analysis) {
			os.Exit(1)
		}
		coverage, testErr := contentcompiler.Simulate(bundle, 32, 1)
		if testErr != nil {
			fail(testErr)
		}
		if coverage.CompletedRuns != coverage.Runs {
			fail(fmt.Errorf("only %d/%d content test runs completed", coverage.CompletedRuns, coverage.Runs))
		}
		fmt.Printf("content tests: %d/%d completed, action coverage %.1f%%, choice coverage %.1f%%\n", coverage.CompletedRuns, coverage.Runs, coverage.ActionCoverage*100, coverage.ChoiceCoverage*100)
	case "graph":
		fmt.Print(contentcompiler.Mermaid(bundle))
	case "simulate":
		flags := flag.NewFlagSet("simulate", flag.ExitOnError)
		runs := flags.Int("runs", 200, "number of randomized playthroughs")
		seed := flags.Int64("seed", 1, "base random seed")
		_ = flags.Parse(os.Args[3:])
		coverage, simulateErr := contentcompiler.Simulate(bundle, *runs, *seed)
		if simulateErr != nil {
			fail(simulateErr)
		}
		data, marshalErr := contentcompiler.WriteJSON(coverage)
		if marshalErr != nil {
			fail(marshalErr)
		}
		fmt.Println(string(data))
	default:
		usage()
		os.Exit(2)
	}
}

func printAnalysis(report contentcompiler.Analysis) {
	for _, item := range report.Diagnostics {
		location := item.File
		if item.Line > 0 {
			location = fmt.Sprintf("%s:%d", location, item.Line)
		}
		fmt.Printf("%s: %s [%s] %s\n", location, item.Severity, item.Code, item.Message)
	}
	fmt.Printf("%s: %d files, %d arcs, %d nodes, %d choices, %d actions, %d flags, %d facts, %d locations, %d actors\n", report.ScenarioID, report.Files, report.Arcs, report.Nodes, report.Choices, report.Actions, report.Flags, report.Facts, report.Locations, report.Actors)
}

func usage() {
	fmt.Fprintln(os.Stderr, "usage: fantu-content <validate|graph|test|simulate> <scenario-dir> [--runs N] [--seed N]")
}
func fail(err error) { fmt.Fprintln(os.Stderr, "fantu-content:", err); os.Exit(1) }

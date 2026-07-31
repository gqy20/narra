package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"

	"fantu/internal/engine"
	"fantu/internal/report"
	"fantu/internal/scenario"
)

func main() {
	dataDir := flag.String("data", filepath.FromSlash("data/blackwind"), "scenario data directory")
	planPath := flag.String("plan", "", "optional player run plan JSON")
	output := flag.String("out", "", "report output path; stdout when empty")
	format := flag.String("format", "markdown", "report format: markdown or json")
	until := flag.Int("until", 0, "run through this day; defaults to scenario duration")
	flag.Parse()

	bundle, err := scenario.Load(*dataDir)
	if err != nil {
		fail(err)
	}
	var simulation *engine.Engine
	if *planPath == "" {
		simulation = engine.New(bundle)
	} else {
		plan, loadErr := scenario.LoadPlan(*planPath, bundle)
		if loadErr != nil {
			fail(loadErr)
		}
		simulation = engine.NewWithPlan(bundle, plan)
	}
	targetDay := *until
	if targetDay == 0 {
		targetDay = bundle.Scenario.Duration
	}
	state, err := simulation.RunUntil(targetDay)
	if err != nil {
		fail(err)
	}

	writer := os.Stdout
	if *output != "" {
		if err := os.MkdirAll(filepath.Dir(*output), 0o755); err != nil {
			fail(err)
		}
		writer, err = os.Create(*output)
		if err != nil {
			fail(err)
		}
		defer writer.Close()
	}

	switch *format {
	case "markdown":
		err = report.Markdown(writer, state, bundle)
	case "json":
		err = report.JSON(writer, state)
	default:
		err = fmt.Errorf("unsupported format %q", *format)
	}
	if err != nil {
		fail(err)
	}
}

func fail(err error) {
	fmt.Fprintln(os.Stderr, "sim:", err)
	os.Exit(1)
}

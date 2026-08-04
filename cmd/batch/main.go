package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"

	"narra/internal/batch"
	"narra/internal/scenario"
)

func main() {
	dataDir := flag.String("data", filepath.FromSlash("data/blackwind"), "scenario data directory")
	plansDir := flag.String("plans", "testdata", "directory containing run plan JSON files")
	output := flag.String("out", filepath.FromSlash("output/batch.md"), "Markdown report output path")
	includeBaseline := flag.Bool("baseline", true, "include the no-player baseline")
	sweepSeeds := flag.Int("sweep", 0, "run a parameter sweep with this many seeds (0 keeps fixed mode)")
	seedStart := flag.Int64("seed-start", 1, "first parameter sweep seed")
	resourceDelta := flag.Int("resource-delta", 2, "maximum initial resource perturbation")
	relationshipDelta := flag.Int("relationship-delta", 2, "maximum initial directional relationship perturbation")
	costDelta := flag.Int("cost-delta", 2, "maximum strategy cost perturbation")
	beliefDelta := flag.Int("belief-delta", 0, "maximum initial belief confidence/source/presence perturbation (0..2)")
	worldDelta := flag.Int("world-delta", 0, "perturb unique owners, market stock, and one route edge (0..1)")
	flag.Parse()

	bundle, err := scenario.Load(*dataDir)
	if err != nil {
		fail(err)
	}
	plans, err := batch.LoadPlans(*plansDir, bundle)
	if err != nil {
		fail(err)
	}
	var summary batch.Summary
	if *sweepSeeds > 0 {
		seeds := make([]int64, *sweepSeeds)
		for i := range seeds {
			seeds[i] = *seedStart + int64(i)
		}
		summary, err = batch.RunSweep(bundle, plans, *includeBaseline, batch.SweepConfig{
			Seeds: seeds, ResourceDelta: *resourceDelta,
			RelationshipDelta: *relationshipDelta, CostDelta: *costDelta,
			BeliefDelta: *beliefDelta,
			WorldDelta:  *worldDelta,
		})
	} else {
		summary, err = batch.Run(bundle, plans, *includeBaseline)
	}
	if err != nil {
		fail(err)
	}
	if err := os.MkdirAll(filepath.Dir(*output), 0o755); err != nil {
		fail(err)
	}
	file, err := os.Create(*output)
	if err != nil {
		fail(err)
	}
	defer file.Close()
	if err := batch.Markdown(file, summary); err != nil {
		fail(err)
	}
	fmt.Printf("batch: %d runs, %d owners, %d warnings -> %s\n", len(summary.Results), len(summary.OwnerDistribution), len(summary.Warnings), *output)
}

func fail(err error) {
	fmt.Fprintln(os.Stderr, "batch:", err)
	os.Exit(1)
}

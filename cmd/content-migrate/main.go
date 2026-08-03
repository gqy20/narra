package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"

	"fantu/internal/scenario"
)

func main() {
	dataDir := flag.String("data", "data/blackwind", "content package directory")
	write := flag.Bool("write", false, "apply the migration after validating the result")
	jsonOutput := flag.Bool("json", false, "print the migration report as JSON")
	flag.Parse()
	report, err := scenario.MigrateContent(*dataDir, *write)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	if *jsonOutput {
		encoder := json.NewEncoder(os.Stdout)
		encoder.SetIndent("", "  ")
		_ = encoder.Encode(report)
		return
	}
	fmt.Printf("Content schema %d -> %d\n", report.FromVersion, report.ToVersion)
	for _, change := range report.Changes {
		fmt.Println("-", change)
	}
	for _, file := range report.Files {
		fmt.Printf("- %s\n  %s -> %s\n", file.Path, file.BeforeHash, file.AfterHash)
	}
	if len(report.Files) == 0 {
		fmt.Println("No migration required.")
	} else if report.Applied {
		fmt.Println("Migration applied and validated.")
	} else {
		fmt.Println("Preview only; rerun with -write to apply.")
	}
}

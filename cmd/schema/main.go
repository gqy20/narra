package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"

	"narra/internal/server"
)

func main() {
	output := flag.String("out", filepath.Join("api", "v1-response.schema.json"), "schema output path")
	flag.Parse()
	data, err := server.ContractJSON()
	if err != nil {
		fatal(err)
	}
	if err := os.MkdirAll(filepath.Dir(*output), 0o755); err != nil {
		fatal(err)
	}
	if err := os.WriteFile(*output, data, 0o644); err != nil {
		fatal(err)
	}
}

func fatal(err error) {
	fmt.Fprintln(os.Stderr, err)
	os.Exit(1)
}

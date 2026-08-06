// Package testsupport contains repository-aware helpers shared by tests.
// It must not be imported by production packages.
package testsupport

import (
	"path/filepath"
	"runtime"

	"narra/internal/domain"
	"narra/internal/scenario"
)

// TB is the subset of testing.TB needed by these helpers.
type TB interface {
	Helper()
	Fatalf(format string, args ...any)
}

// RepositoryRoot returns the absolute repository root based on this source file.
func RepositoryRoot(tb TB) string {
	tb.Helper()
	_, sourceFile, _, ok := runtime.Caller(0)
	if !ok {
		tb.Fatalf("resolve testsupport source path")
	}
	return filepath.Clean(filepath.Join(filepath.Dir(sourceFile), "..", ".."))
}

// OfficialWorldPath returns the canonical path of an official content package.
// Tests outside the scenario/content compiler packages should use this helper so
// their dependency on production content remains explicit and searchable.
func OfficialWorldPath(tb TB, name string) string {
	tb.Helper()
	if name == "" || name == "." || name == ".." || filepath.Base(name) != name {
		tb.Fatalf("unsafe official test world name %q", name)
	}
	return filepath.Join(RepositoryRoot(tb), "data", name)
}

// LoadOfficialWorld loads an official package for an acceptance or portability test.
// Generic unit tests should instead construct the smallest test-owned bundle they need.
func LoadOfficialWorld(tb TB, name string) domain.Bundle {
	tb.Helper()
	bundle, err := scenario.Load(OfficialWorldPath(tb, name))
	if err != nil {
		tb.Fatalf("load official world %s: %v", name, err)
	}
	return bundle
}

// TestdataPath returns a canonical path below the repository testdata directory.
func TestdataPath(tb TB, elements ...string) string {
	tb.Helper()
	parts := append([]string{RepositoryRoot(tb), "testdata"}, elements...)
	return filepath.Join(parts...)
}

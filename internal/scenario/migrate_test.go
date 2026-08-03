package scenario

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestContentMigrationPreviewAndApply(t *testing.T) {
	sourceDir := filepath.Join("..", "..", "data", "blackwind")
	targetDir := t.TempDir()
	entries, err := os.ReadDir(sourceDir)
	if err != nil {
		t.Fatal(err)
	}
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		contents, err := os.ReadFile(filepath.Join(sourceDir, entry.Name()))
		if err != nil {
			t.Fatal(err)
		}
		if entry.Name() == "manifest.yml" {
			contents = []byte(strings.Replace(string(contents), "schema_version: 3", "schema_version: 1", 1))
		}
		if entry.Name() == "arcs.yml" {
			lines := strings.Split(strings.ReplaceAll(string(contents), "\r\n", "\n"), "\n")
			filtered := lines[:0]
			for _, line := range lines {
				if strings.HasPrefix(line, "          feedback:") {
					continue
				}
				filtered = append(filtered, line)
			}
			contents = []byte(strings.Join(filtered, "\n"))
		}
		if err := os.WriteFile(filepath.Join(targetDir, entry.Name()), contents, 0o644); err != nil {
			t.Fatal(err)
		}
	}

	manifestBefore, _ := os.ReadFile(filepath.Join(targetDir, "manifest.yml"))
	preview, err := MigrateContent(targetDir, false)
	if err != nil {
		t.Fatalf("preview migration: %v", err)
	}
	if preview.FromVersion != 1 || preview.ToVersion != CurrentSchemaVersion || preview.Applied || len(preview.Files) != 2 || len(preview.Changes) < 2 {
		t.Fatalf("preview report = %+v", preview)
	}
	manifestAfterPreview, _ := os.ReadFile(filepath.Join(targetDir, "manifest.yml"))
	if string(manifestAfterPreview) != string(manifestBefore) {
		t.Fatal("preview modified the content package")
	}

	applied, err := MigrateContent(targetDir, true)
	if err != nil {
		t.Fatalf("apply migration: %v", err)
	}
	if !applied.Applied {
		t.Fatalf("applied report = %+v", applied)
	}
	bundle, err := Load(targetDir)
	if err != nil {
		t.Fatalf("load migrated package: %v", err)
	}
	if bundle.Content.SchemaVersion != CurrentSchemaVersion || len(bundle.StoryArcs["qinglan_intel"].Nodes[0].Choices[0].Feedback.Messages) == 0 {
		t.Fatalf("migrated bundle = %+v", bundle.Content)
	}
	if message := bundle.StoryArcs["qinglan_intel"].Nodes[0].Choices[0].Feedback.Messages[0]; strings.Contains(message, "�") {
		t.Fatalf("migrated feedback contains invalid text: %q", message)
	}
	noOp, err := MigrateContent(targetDir, false)
	if err != nil || len(noOp.Files) != 0 {
		t.Fatalf("current package migration = %+v, %v", noOp, err)
	}
}

func TestContentMigrationV2AddsPresentationMetadata(t *testing.T) {
	sourceDir := filepath.Join("..", "..", "data", "blackwind")
	targetDir := t.TempDir()
	entries, err := os.ReadDir(sourceDir)
	if err != nil {
		t.Fatal(err)
	}
	for _, entry := range entries {
		if entry.IsDir() || entry.Name() == "presentation.yml" {
			continue
		}
		contents, err := os.ReadFile(filepath.Join(sourceDir, entry.Name()))
		if err != nil {
			t.Fatal(err)
		}
		if entry.Name() == "manifest.yml" {
			contents = []byte(strings.Replace(string(contents), "schema_version: 3", "schema_version: 2", 1))
		}
		if err := os.WriteFile(filepath.Join(targetDir, entry.Name()), contents, 0o644); err != nil {
			t.Fatal(err)
		}
	}
	report, err := MigrateContent(targetDir, true)
	if err != nil {
		t.Fatalf("apply v2 migration: %v", err)
	}
	if !report.Applied {
		t.Fatalf("migration report = %+v", report)
	}
	bundle, err := Load(targetDir)
	if err != nil {
		t.Fatalf("load migrated v2 package: %v", err)
	}
	if bundle.Presentation.Brand == "" || len(bundle.Presentation.Resources) != len(bundle.DefaultPlayer.Resources) {
		t.Fatalf("generated presentation = %+v", bundle.Presentation)
	}
}

func TestContentMigrationRejectsFutureSchema(t *testing.T) {
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "manifest.yml"), []byte("schema_version: 99\ncontent_version: test\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "arcs.yml"), []byte("[]\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := MigrateContent(dir, false); err == nil || !strings.Contains(err.Error(), "newer than supported") {
		t.Fatalf("future schema error = %v", err)
	}
}

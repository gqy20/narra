package testsupport

import (
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

func TestTestsDoNotBypassOfficialWorldBoundary(t *testing.T) {
	root := RepositoryRoot(t)
	var violations []string
	err := filepath.WalkDir(root, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() {
			if entry.Name() == ".git" || entry.Name() == "dist" || entry.Name() == "artifacts" {
				return filepath.SkipDir
			}
			return nil
		}
		if !strings.HasSuffix(entry.Name(), "_test.go") {
			return nil
		}
		relative, err := filepath.Rel(root, path)
		if err != nil {
			return err
		}
		slashPath := filepath.ToSlash(relative)
		if strings.HasPrefix(slashPath, "internal/scenario/") ||
			strings.HasPrefix(slashPath, "internal/contentcompiler/") ||
			strings.HasPrefix(slashPath, "internal/testsupport/") {
			return nil
		}
		parsed, err := parser.ParseFile(token.NewFileSet(), path, nil, 0)
		if err != nil {
			return err
		}
		bypassesBoundary := false
		ast.Inspect(parsed, func(node ast.Node) bool {
			literal, ok := node.(*ast.BasicLit)
			if !ok || literal.Kind != token.STRING {
				return true
			}
			value, err := strconv.Unquote(literal.Value)
			if err != nil {
				return true
			}
			normalized := strings.ReplaceAll(value, `\`, "/")
			if normalized == "data" || strings.HasPrefix(normalized, "data/") || strings.Contains(normalized, "../data/") {
				bypassesBoundary = true
				return false
			}
			return true
		})
		if bypassesBoundary {
			violations = append(violations, slashPath)
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(violations) > 0 {
		t.Fatalf("tests bypass internal/testsupport official-world boundary: %s", strings.Join(violations, ", "))
	}
}

func TestProductionCodeDoesNotImportTestsupport(t *testing.T) {
	root := RepositoryRoot(t)
	var violations []string
	err := filepath.WalkDir(root, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() {
			if entry.Name() == ".git" || entry.Name() == "dist" || entry.Name() == "artifacts" {
				return filepath.SkipDir
			}
			return nil
		}
		if filepath.Ext(entry.Name()) != ".go" || strings.HasSuffix(entry.Name(), "_test.go") {
			return nil
		}
		relative, err := filepath.Rel(root, path)
		if err != nil {
			return err
		}
		slashPath := filepath.ToSlash(relative)
		if strings.HasPrefix(slashPath, "internal/testsupport/") {
			return nil
		}
		content, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		if strings.Contains(string(content), `"narra/internal/testsupport"`) {
			violations = append(violations, slashPath)
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(violations) > 0 {
		t.Fatalf("production code imports internal/testsupport: %s", strings.Join(violations, ", "))
	}
}

func TestDeterministicVerificationCannotShortCircuitAfterDocs(t *testing.T) {
	scriptPath := filepath.Join(RepositoryRoot(t), "tools", "verify.ps1")
	content, err := os.ReadFile(scriptPath)
	if err != nil {
		t.Fatal(err)
	}
	script := string(content)
	docsCall := strings.Index(script, `verify-docs.ps1`)
	formatCheck := strings.Index(script, `gofmt -l .`)
	goTests := strings.Index(script, `go test ./...`)
	goVet := strings.Index(script, `go vet ./...`)
	contentTests := strings.Index(script, `narra-content test`)
	if docsCall < 0 || formatCheck <= docsCall || goTests <= formatCheck || goVet <= goTests || contentTests <= goVet {
		t.Fatalf("tools/verify.ps1 lost its docs, format, test, vet, or content verification order")
	}
	if strings.Contains(script[docsCall:formatCheck], `$LASTEXITCODE`) {
		t.Fatal("tools/verify.ps1 inspects LASTEXITCODE after a PowerShell child script and may report a false successful short circuit")
	}
}

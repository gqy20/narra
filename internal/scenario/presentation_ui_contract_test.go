package scenario

import (
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"testing"
)

func TestPresentationUIContractCoversRuntimeReferences(t *testing.T) {
	references := make(map[string][]string)
	goCalls := make(map[string][]presentationUIGoCall)
	root := filepath.Join("..", "..")
	goFiles, err := filepath.Glob(filepath.Join(root, "internal", "app", "*.go"))
	if err != nil {
		t.Fatal(err)
	}
	for _, path := range goFiles {
		if strings.HasSuffix(path, "_test.go") {
			continue
		}
		collectGoPresentationUIReferences(t, path, references, goCalls)
	}
	gdFiles, err := filepath.Glob(filepath.Join(root, "godot", "scripts", "*.gd"))
	if err != nil {
		t.Fatal(err)
	}
	for _, path := range gdFiles {
		collectGodotPresentationUIReferences(t, path, references)
	}

	missing := make([]string, 0)
	for key, locations := range references {
		if _, ok := presentationUIContract.Keys[key]; !ok && !presentationUIDynamicPrefix(key) {
			missing = append(missing, key+" at "+strings.Join(locations, ", "))
		}
	}
	sort.Strings(missing)
	if len(missing) > 0 {
		t.Fatalf("runtime presentation UI references are missing from the contract:\n%s", strings.Join(missing, "\n"))
	}
	for key, calls := range goCalls {
		rule, ok := presentationUIContract.Keys[key]
		if !ok {
			continue
		}
		for _, call := range calls {
			if !equalStrings(call.Named, rule.Named) {
				t.Errorf("presentation UI call %s at %s supplies named placeholders %v, contract requires %v", key, call.Location, call.Named, rule.Named)
			}
		}
	}
}

type presentationUIGoCall struct {
	Named    []string
	Location string
}

func presentationUIDynamicPrefix(key string) bool {
	for _, prefix := range presentationUIContract.DynamicPrefixes {
		if key == prefix {
			return true
		}
	}
	return false
}

func TestValidateRejectsIncompletePresentationUIContract(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatal(err)
	}
	delete(bundle.Presentation.UI, "action_buy_name")
	if err := Validate(bundle); err == nil || !strings.Contains(err.Error(), "presentation ui requires action_buy_name") {
		t.Fatalf("missing presentation UI error = %v", err)
	}
}

func TestValidateRejectsPresentationUIPlaceholderDrift(t *testing.T) {
	bundle, err := Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatal(err)
	}
	bundle.Presentation.UI["action_buy_name"] = "购买物品"
	if err := Validate(bundle); err == nil || !strings.Contains(err.Error(), "action_buy_name named placeholders") {
		t.Fatalf("named placeholder error = %v", err)
	}
	bundle, err = Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatal(err)
	}
	bundle.Presentation.UI["action_send_clues_menu"] = "向%s传递线索"
	if err := Validate(bundle); err == nil || !strings.Contains(err.Error(), "action_send_clues_menu printf placeholders") {
		t.Fatalf("printf placeholder error = %v", err)
	}
}

func collectGoPresentationUIReferences(t *testing.T, path string, references map[string][]string, calls map[string][]presentationUIGoCall) {
	t.Helper()
	set := token.NewFileSet()
	file, err := parser.ParseFile(set, path, nil, 0)
	if err != nil {
		t.Fatal(err)
	}
	ast.Inspect(file, func(node ast.Node) bool {
		call, ok := node.(*ast.CallExpr)
		if !ok || len(call.Args) == 0 {
			return true
		}
		selector, ok := call.Fun.(*ast.SelectorExpr)
		if !ok || selector.Sel.Name != "uiText" {
			return true
		}
		literal, ok := call.Args[0].(*ast.BasicLit)
		if !ok || literal.Kind != token.STRING {
			return true
		}
		key, err := strconv.Unquote(literal.Value)
		if err != nil {
			t.Fatal(err)
		}
		position := set.Position(call.Pos())
		location := filepath.ToSlash(path) + ":" + strconv.Itoa(position.Line)
		references[key] = append(references[key], location)
		placeholders := make([]string, 0, len(call.Args)/2)
		for index := 1; index < len(call.Args); index += 2 {
			placeholder, ok := call.Args[index].(*ast.BasicLit)
			if !ok || placeholder.Kind != token.STRING {
				t.Errorf("presentation UI call %s at %s has a non-literal placeholder name", key, location)
				continue
			}
			name, err := strconv.Unquote(placeholder.Value)
			if err != nil {
				t.Fatal(err)
			}
			placeholders = append(placeholders, name)
		}
		sort.Strings(placeholders)
		calls[key] = append(calls[key], presentationUIGoCall{Named: placeholders, Location: location})
		return true
	})
}

var godotPresentationUIReference = regexp.MustCompile(`(?:_ui_text|presentation_registry\.ui_text)\(\s*"([^"]+)"`)

func collectGodotPresentationUIReferences(t *testing.T, path string, references map[string][]string) {
	t.Helper()
	contents, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	for _, match := range godotPresentationUIReference.FindAllSubmatchIndex(contents, -1) {
		key := string(contents[match[2]:match[3]])
		line := 1 + strings.Count(string(contents[:match[0]]), "\n")
		references[key] = append(references[key], filepath.ToSlash(path)+":"+strconv.Itoa(line))
	}
}

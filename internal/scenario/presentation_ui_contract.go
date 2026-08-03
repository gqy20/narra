package scenario

import (
	_ "embed"
	"fmt"
	"regexp"
	"sort"
	"strings"

	"go.yaml.in/yaml/v4"
)

type presentationUIRule struct {
	Named  []string `yaml:"named,omitempty"`
	Printf []string `yaml:"printf,omitempty"`
}

type presentationUIContractFile struct {
	DynamicPrefixes []string                      `yaml:"dynamic_prefixes,omitempty"`
	Keys            map[string]presentationUIRule `yaml:"keys"`
}

//go:embed presentation_ui_contract.yml
var presentationUIContractSource []byte

var presentationUIContract = mustLoadPresentationUIContract()

var (
	namedPresentationPlaceholder  = regexp.MustCompile(`\{([a-z][a-z0-9_]*)\}`)
	printfPresentationPlaceholder = regexp.MustCompile(`%([sd])`)
)

func mustLoadPresentationUIContract() presentationUIContractFile {
	var contract presentationUIContractFile
	if err := yaml.Unmarshal(presentationUIContractSource, &contract); err != nil {
		panic(fmt.Sprintf("decode embedded presentation UI contract: %v", err))
	}
	if len(contract.Keys) == 0 {
		panic("embedded presentation UI contract has no keys")
	}
	return contract
}

func validatePresentationUI(ui map[string]string) error {
	keys := make([]string, 0, len(presentationUIContract.Keys))
	for key := range presentationUIContract.Keys {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	for _, key := range keys {
		rule := presentationUIContract.Keys[key]
		value := strings.TrimSpace(ui[key])
		if value == "" {
			return fmt.Errorf("presentation ui requires %s", key)
		}
		if actual := namedPresentationPlaceholders(value); !equalStrings(actual, rule.Named) {
			return fmt.Errorf("presentation ui %s named placeholders = %v, want %v", key, actual, rule.Named)
		}
		if actual := printfPresentationPlaceholders(value); !equalStrings(actual, rule.Printf) {
			return fmt.Errorf("presentation ui %s printf placeholders = %v, want %v", key, actual, rule.Printf)
		}
	}
	return nil
}

func namedPresentationPlaceholders(value string) []string {
	seen := make(map[string]bool)
	for _, match := range namedPresentationPlaceholder.FindAllStringSubmatch(value, -1) {
		seen[match[1]] = true
	}
	result := make([]string, 0, len(seen))
	for placeholder := range seen {
		result = append(result, placeholder)
	}
	sort.Strings(result)
	return result
}

func printfPresentationPlaceholders(value string) []string {
	matches := printfPresentationPlaceholder.FindAllStringSubmatch(value, -1)
	result := make([]string, 0, len(matches))
	for _, match := range matches {
		result = append(result, match[1])
	}
	return result
}

func equalStrings(left, right []string) bool {
	if len(left) != len(right) {
		return false
	}
	for index := range left {
		if left[index] != right[index] {
			return false
		}
	}
	return true
}

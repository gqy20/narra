package scenario

import (
	"bytes"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"fantu/internal/domain"
	"go.yaml.in/yaml/v4"
)

const CurrentSchemaVersion = 5

type manifest struct {
	SchemaVersion       int    `json:"schema_version"`
	ContentVersion      string `json:"content_version"`
	EngineCompatibility string `json:"engine_compatibility,omitempty"`
}

func Load(dir string) (domain.Bundle, error) {
	var bundle domain.Bundle
	loadedFiles := make([]string, 0, 10)
	var metadata manifest
	manifestPath, err := readDataFile(dir, "manifest", &metadata)
	if err != nil {
		return bundle, err
	}
	if metadata.SchemaVersion != CurrentSchemaVersion {
		return bundle, fmt.Errorf("manifest uses unsupported schema version %d; run content-migrate", metadata.SchemaVersion)
	}
	if strings.TrimSpace(metadata.ContentVersion) == "" {
		return bundle, fmt.Errorf("manifest requires content_version")
	}
	loadedFiles = append(loadedFiles, manifestPath)

	path, err := readDataFile(dir, "scenario", &bundle.Scenario)
	if err != nil {
		return bundle, err
	}
	loadedFiles = append(loadedFiles, path)

	path, err = readDataFile(dir, "presentation", &bundle.Presentation)
	if err != nil {
		return bundle, err
	}
	loadedFiles = append(loadedFiles, path)

	path, err = readDataFile(dir, "dialogue", &bundle.Dialogue)
	if err != nil {
		return bundle, err
	}
	loadedFiles = append(loadedFiles, path)

	path, err = readDataFile(dir, "rules", &bundle.Rules)
	if err != nil {
		return bundle, err
	}
	loadedFiles = append(loadedFiles, path)

	var arcs []domain.StoryArc
	path, err = readDataFile(dir, "arcs", &arcs)
	if err != nil {
		return bundle, err
	}
	loadedFiles = append(loadedFiles, path)
	bundle.StoryArcs = make(map[string]domain.StoryArc, len(arcs))
	for _, arc := range arcs {
		if _, exists := bundle.StoryArcs[arc.ID]; exists {
			return bundle, fmt.Errorf("duplicate story arc id %q", arc.ID)
		}
		bundle.StoryArcs[arc.ID] = arc
	}

	var flags []domain.FlagDefinition
	path, err = readDataFile(dir, "flags", &flags)
	if err != nil {
		return bundle, err
	}
	loadedFiles = append(loadedFiles, path)
	bundle.Flags = make(map[string]domain.FlagDefinition, len(flags))
	for _, flag := range flags {
		key := flag.Scope + ":" + flag.ID
		if _, exists := bundle.Flags[key]; exists {
			return bundle, fmt.Errorf("duplicate flag %q", key)
		}
		bundle.Flags[key] = flag
	}

	var actions []domain.ActionDefinition
	path, err = readDataFile(dir, "actions", &actions)
	if err != nil {
		return bundle, err
	}
	loadedFiles = append(loadedFiles, path)
	bundle.Actions = make(map[string]domain.ActionDefinition, len(actions))
	for _, action := range actions {
		if _, exists := bundle.Actions[action.ID]; exists {
			return bundle, fmt.Errorf("duplicate action id %q", action.ID)
		}
		bundle.Actions[action.ID] = action
	}

	var facts []domain.Fact
	path, err = readDataFile(dir, "facts", &facts)
	if err != nil {
		return bundle, err
	}
	loadedFiles = append(loadedFiles, path)
	bundle.Facts = make(map[string]domain.Fact, len(facts))
	for _, fact := range facts {
		if _, exists := bundle.Facts[fact.ID]; exists {
			return bundle, fmt.Errorf("duplicate fact id %q", fact.ID)
		}
		bundle.Facts[fact.ID] = fact
	}

	path, err = readDataFile(dir, "npcs", &bundle.NPCs)
	if err != nil {
		return bundle, err
	}
	loadedFiles = append(loadedFiles, path)

	var items []domain.ItemDefinition
	path, err = readDataFile(dir, "items", &items)
	if err != nil {
		return bundle, err
	}
	loadedFiles = append(loadedFiles, path)
	bundle.Items = make(map[string]domain.ItemDefinition, len(items))
	for _, item := range items {
		if _, exists := bundle.Items[item.ID]; exists {
			return bundle, fmt.Errorf("duplicate item id %q", item.ID)
		}
		bundle.Items[item.ID] = item
	}

	var locations []domain.Location
	path, err = readDataFile(dir, "locations", &locations)
	if err != nil {
		return bundle, err
	}
	loadedFiles = append(loadedFiles, path)
	bundle.Locations = make(map[string]domain.Location, len(locations))
	for _, location := range locations {
		if _, exists := bundle.Locations[location.ID]; exists {
			return bundle, fmt.Errorf("duplicate location id %q", location.ID)
		}
		bundle.Locations[location.ID] = location
	}

	path, err = readDataFile(dir, "player", &bundle.DefaultPlayer)
	if err != nil {
		return bundle, err
	}
	loadedFiles = append(loadedFiles, path)
	hash, err := contentHash(dir, loadedFiles)
	if err != nil {
		return bundle, err
	}
	bundle.Content = domain.ContentMetadata{
		SchemaVersion: metadata.SchemaVersion, Version: metadata.ContentVersion,
		Hash: hash, EngineCompatibility: metadata.EngineCompatibility,
	}

	if err := Validate(bundle); err != nil {
		return bundle, err
	}
	return bundle, nil
}

func LoadPlan(path string, bundle domain.Bundle) (domain.RunPlan, error) {
	var plan domain.RunPlan
	if err := decodeFile(path, &plan); err != nil {
		return plan, err
	}
	if plan.ID == "" || plan.Player.ID == "" {
		return plan, fmt.Errorf("run plan requires id and player id")
	}
	if _, ok := bundle.Locations[plan.Player.Location]; !ok {
		return plan, fmt.Errorf("player references unknown location %s", plan.Player.Location)
	}
	for _, belief := range plan.Player.Beliefs {
		if _, ok := bundle.Facts[belief.FactID]; !ok {
			return plan, fmt.Errorf("player references unknown fact %s", belief.FactID)
		}
	}
	for _, command := range plan.Commands {
		if err := validateCommand(command, command.Day, plan.Player.ID, bundle, 0); err != nil {
			return plan, err
		}
	}
	return plan, nil
}

func validateCommand(command domain.PlayerCommand, scheduledDay int, actorID string, bundle domain.Bundle, depth int) error {
	if depth > 8 {
		return fmt.Errorf("command %s fallback nesting exceeds 8 levels", command.ID)
	}
	if command.ID == "" {
		return fmt.Errorf("player command requires id")
	}
	if depth == 0 {
		if command.Day < 1 || command.Day > bundle.Scenario.Duration {
			return fmt.Errorf("command %s has invalid day %d", command.ID, command.Day)
		}
	} else if command.Day != 0 && command.Day != scheduledDay {
		return fmt.Errorf("fallback command %s must omit day or use parent day %d", command.ID, scheduledDay)
	}
	action, ok := bundle.Actions[command.ActionID]
	if !ok {
		return fmt.Errorf("command %s references unknown action %s", command.ID, command.ActionID)
	}
	if err := validateStaticMovement(action.Duration, command.Duration, command.Conditions, command.Effects, actorID, bundle); err != nil {
		return fmt.Errorf("command %s: %w", command.ID, err)
	}
	if err := validateCosts(command.Costs); err != nil {
		return fmt.Errorf("command %s: %w", command.ID, err)
	}
	if err := validateConditionsAndEffects(command.Conditions, command.CompletionConditions, command.Effects, bundle); err != nil {
		return fmt.Errorf("command %s: %w", command.ID, err)
	}
	switch command.OnFailure {
	case "", "error", "skip":
		if command.Fallback != nil {
			return fmt.Errorf("command %s has fallback but on_failure is not fallback", command.ID)
		}
	case "fallback":
		if command.Fallback == nil {
			return fmt.Errorf("command %s uses fallback policy without fallback command", command.ID)
		}
		if err := validateCommand(*command.Fallback, scheduledDay, actorID, bundle, depth+1); err != nil {
			return err
		}
	default:
		return fmt.Errorf("command %s has unknown on_failure policy %q", command.ID, command.OnFailure)
	}
	return nil
}

func readDataFile(dir, base string, target any) (string, error) {
	for _, extension := range []string{".yml", ".yaml", ".json"} {
		path := filepath.Join(dir, base+extension)
		if _, err := os.Stat(path); err == nil {
			if err := decodeFile(path, target); err != nil {
				return "", err
			}
			return path, nil
		} else if !os.IsNotExist(err) {
			return "", fmt.Errorf("stat %s: %w", path, err)
		}
	}
	return "", fmt.Errorf("read %s: no .yml, .yaml, or .json content file", filepath.Join(dir, base))
}

func decodeFile(path string, target any) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("read %s: %w", path, err)
	}
	switch strings.ToLower(filepath.Ext(path)) {
	case ".yml", ".yaml":
		if err := decodeYAML(data, target); err != nil {
			return fmt.Errorf("decode %s: %w", path, err)
		}
	case ".json":
		if err := decodeJSON(data, target); err != nil {
			return fmt.Errorf("decode %s: %w", path, err)
		}
	default:
		return fmt.Errorf("decode %s: unsupported extension", path)
	}
	return nil
}

func decodeJSON(data []byte, target any) error {
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		return err
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		if err == nil {
			return fmt.Errorf("multiple documents are not allowed")
		}
		return err
	}
	return nil
}

func decodeYAML(data []byte, target any) error {
	decoder := yaml.NewDecoder(bytes.NewReader(data))
	var value any
	if err := decoder.Decode(&value); err != nil {
		return err
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		if err == nil {
			return fmt.Errorf("multiple documents are not allowed")
		}
		return err
	}
	normalized, err := json.Marshal(value)
	if err != nil {
		return fmt.Errorf("normalize YAML: %w", err)
	}
	if err := decodeJSON(normalized, target); err != nil {
		return err
	}
	return nil
}

func contentHash(root string, paths []string) (string, error) {
	sort.Strings(paths)
	hash := sha256.New()
	for _, path := range paths {
		data, err := os.ReadFile(path)
		if err != nil {
			return "", fmt.Errorf("hash %s: %w", path, err)
		}
		relative, err := filepath.Rel(root, path)
		if err != nil {
			return "", fmt.Errorf("hash path %s: %w", path, err)
		}
		hash.Write([]byte(filepath.ToSlash(relative)))
		hash.Write([]byte{0})
		hash.Write(data)
		hash.Write([]byte{0})
	}
	return fmt.Sprintf("sha256:%x", hash.Sum(nil)), nil
}

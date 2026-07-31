package scenario

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"fantu/internal/domain"
)

func Load(dir string) (domain.Bundle, error) {
	var bundle domain.Bundle
	if err := readJSON(filepath.Join(dir, "scenario.json"), &bundle.Scenario); err != nil {
		return bundle, err
	}

	var actions []domain.ActionDefinition
	if err := readJSON(filepath.Join(dir, "actions.json"), &actions); err != nil {
		return bundle, err
	}
	bundle.Actions = make(map[string]domain.ActionDefinition, len(actions))
	for _, action := range actions {
		bundle.Actions[action.ID] = action
	}

	var facts []domain.Fact
	if err := readJSON(filepath.Join(dir, "facts.json"), &facts); err != nil {
		return bundle, err
	}
	bundle.Facts = make(map[string]domain.Fact, len(facts))
	for _, fact := range facts {
		bundle.Facts[fact.ID] = fact
	}

	if err := readJSON(filepath.Join(dir, "npcs.json"), &bundle.NPCs); err != nil {
		return bundle, err
	}

	var items []domain.ItemDefinition
	if err := readJSON(filepath.Join(dir, "items.json"), &items); err != nil {
		return bundle, err
	}
	bundle.Items = make(map[string]domain.ItemDefinition, len(items))
	for _, item := range items {
		bundle.Items[item.ID] = item
	}

	var locations []domain.Location
	if err := readJSON(filepath.Join(dir, "locations.json"), &locations); err != nil {
		return bundle, err
	}
	bundle.Locations = make(map[string]domain.Location, len(locations))
	for _, location := range locations {
		bundle.Locations[location.ID] = location
	}

	if err := Validate(bundle); err != nil {
		return bundle, err
	}
	return bundle, nil
}

func LoadPlan(path string, bundle domain.Bundle) (domain.RunPlan, error) {
	var plan domain.RunPlan
	if err := readJSON(path, &plan); err != nil {
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

func readJSON(path string, target any) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("read %s: %w", path, err)
	}
	if err := json.Unmarshal(data, target); err != nil {
		return fmt.Errorf("decode %s: %w", path, err)
	}
	return nil
}

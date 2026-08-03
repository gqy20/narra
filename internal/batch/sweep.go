package batch

import (
	"fmt"
	"math/rand"
	"sort"

	"fantu/internal/domain"
	"fantu/internal/engine"
)

// SweepConfig defines reproducible initial-state perturbations. The engine
// remains deterministic; Seed only selects the generated input variant.
type SweepConfig struct {
	Seeds             []int64
	ResourceDelta     int
	RelationshipDelta int
	CostDelta         int
	BeliefDelta       int
	WorldDelta        int
}

func RunSweep(bundle domain.Bundle, plans []domain.RunPlan, includeBaseline bool, cfg SweepConfig) (Summary, error) {
	if err := validateSweepConfig(cfg); err != nil {
		return Summary{}, err
	}
	summary := Summary{
		Title: bundle.Scenario.Title, ContestItemName: contestItemName(bundle),
		OwnerDistribution:  make(map[string]int),
		ActionDistribution: make(map[string]int),
		ResourceFlow:       make(map[string]int),
		FailureFollowUps:   make(map[string]int),
		RuleCoverage:       make(map[string]int),
		Sweep: &SweepInfo{
			Seeds: append([]int64(nil), cfg.Seeds...), ResourceDelta: cfg.ResourceDelta,
			RelationshipDelta: cfg.RelationshipDelta, CostDelta: cfg.CostDelta,
			BeliefDelta: cfg.BeliefDelta,
			WorldDelta:  cfg.WorldDelta,
		},
	}
	for _, seed := range cfg.Seeds {
		variantBundle, variantPlans := perturbInputs(bundle, plans, cfg, seed)
		if includeBaseline {
			state, err := engine.New(variantBundle).Run()
			if err != nil {
				return summary, fmt.Errorf("run baseline seed %d: %w", seed, err)
			}
			summary.add(summarizeSweep(variantBundle, state, seed))
		}
		for _, plan := range variantPlans {
			simulation := engine.NewWithPlan(variantBundle, plan)
			state, err := simulation.Run()
			if err != nil {
				failed := summarizeSweep(variantBundle, simulation.State(), seed)
				failed.Error = err.Error()
				failed.Outcome = "参数扰动后预定命令失效"
				summary.add(failed)
				continue
			}
			summary.add(summarizeSweep(variantBundle, state, seed))
		}
	}
	summary.buildWarnings(bundle, plans)
	return summary, nil
}

func validateSweepConfig(cfg SweepConfig) error {
	if len(cfg.Seeds) == 0 {
		return fmt.Errorf("parameter sweep requires at least one seed")
	}
	if cfg.ResourceDelta < 0 || cfg.RelationshipDelta < 0 || cfg.RelationshipDelta > 5 || cfg.CostDelta < 0 || cfg.BeliefDelta < 0 || cfg.BeliefDelta > 2 || cfg.WorldDelta < 0 || cfg.WorldDelta > 1 {
		return fmt.Errorf("sweep deltas must be non-negative and relationship delta must not exceed 5")
	}
	return nil
}

func summarizeSweep(bundle domain.Bundle, state *domain.WorldState, seed int64) Result {
	result := summarize(bundle, state)
	result.Seed = seed
	result.Swept = true
	result.RunID = fmt.Sprintf("%s/S%d", result.BaseRunID, seed)
	return result
}

func perturbInputs(bundle domain.Bundle, plans []domain.RunPlan, cfg SweepConfig, seed int64) (domain.Bundle, []domain.RunPlan) {
	rng := rand.New(rand.NewSource(seed))
	variant := cloneBundle(bundle)
	perturbWorld(rng, &variant, cfg.WorldDelta)
	edges := make(map[string]domain.Relation)
	for i := range variant.NPCs {
		npc := &variant.NPCs[i]
		perturbResources(rng, npc.Resources, resourceFloorsForStrategies(npc.ID, npc.Strategies), cfg.ResourceDelta)
		perturbBeliefs(rng, npc, variant.Facts, cfg.BeliefDelta)
		for j := range npc.Strategies {
			strategy := &npc.Strategies[j]
			strategy.Score.Cost = clampMin(0, strategy.Score.Cost+delta(rng, cfg.CostDelta))
			if strategy.TargetID != "" && cfg.RelationshipDelta > 0 {
				value := delta(rng, cfg.RelationshipDelta)
				relation := domain.Relation{From: npc.ID, To: strategy.TargetID}
				if value >= 0 {
					relation.Trust = value
				} else {
					relation.Suspicion = -value
				}
				edges[domain.RelationKey(relation.From, relation.To)] = relation
			}
		}
	}
	keys := make([]string, 0, len(edges))
	for key := range edges {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	variant.InitialRelations = make([]domain.Relation, 0, len(keys))
	for _, key := range keys {
		variant.InitialRelations = append(variant.InitialRelations, edges[key])
	}

	variantPlans := clonePlans(plans)
	for i := range variantPlans {
		perturbResources(rng, variantPlans[i].Player.Resources, resourceFloorsForCommands(variantPlans[i].Player.ID, variantPlans[i].Commands), cfg.ResourceDelta)
	}
	return variant, variantPlans
}

func perturbWorld(rng *rand.Rand, bundle *domain.Bundle, amount int) {
	if amount == 0 {
		return
	}
	for i := range bundle.Scenario.Markets {
		market := &bundle.Scenario.Markets[i]
		ids := sortedIntMapKeys(market.Stock)
		for _, itemID := range ids {
			market.Stock[itemID] = clampMin(0, market.Stock[itemID]+delta(rng, amount))
		}
	}
	uniqueIDs := make([]string, 0)
	for itemID, item := range bundle.Items {
		if item.Unique {
			uniqueIDs = append(uniqueIDs, itemID)
		}
	}
	sort.Strings(uniqueIDs)
	if len(uniqueIDs) > 0 {
		itemID := uniqueIDs[rng.Intn(len(uniqueIDs))]
		owners := make([]string, 0, len(bundle.Locations)+len(bundle.NPCs))
		for locationID := range bundle.Locations {
			owners = append(owners, locationID)
		}
		for _, npc := range bundle.NPCs {
			owners = append(owners, npc.ID)
		}
		sort.Strings(owners)
		owner := owners[rng.Intn(len(owners))]
		item := bundle.Items[itemID]
		item.Owner = owner
		bundle.Items[itemID] = item
		for i := range bundle.NPCs {
			bundle.NPCs[i].Items = removeString(bundle.NPCs[i].Items, itemID)
			if bundle.NPCs[i].ID == owner {
				bundle.NPCs[i].Items = append(bundle.NPCs[i].Items, itemID)
			}
		}
	}
	locationIDs := make([]string, 0)
	for locationID, location := range bundle.Locations {
		if len(location.Routes) > 0 {
			locationIDs = append(locationIDs, locationID)
		}
	}
	sort.Strings(locationIDs)
	if len(locationIDs) > 0 {
		locationID := locationIDs[rng.Intn(len(locationIDs))]
		location := bundle.Locations[locationID]
		index := rng.Intn(len(location.Routes))
		location.Routes = append(location.Routes[:index], location.Routes[index+1:]...)
		bundle.Locations[locationID] = location
	}
}

func sortedIntMapKeys(values map[string]int) []string {
	keys := make([]string, 0, len(values))
	for key := range values {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	return keys
}

func removeString(values []string, target string) []string {
	result := values[:0]
	for _, value := range values {
		if value != target {
			result = append(result, value)
		}
	}
	return result
}

func perturbBeliefs(rng *rand.Rand, npc *domain.NPCConfig, facts map[string]domain.Fact, amount int) {
	perturbBeliefList(rng, npc.Beliefs, amount)
	if amount == 0 {
		return
	}
	known := make(map[string]bool)
	for _, belief := range npc.Beliefs {
		known[belief.FactID] = true
	}
	if len(npc.Beliefs) > 1 && rng.Intn(2) == 0 {
		index := rng.Intn(len(npc.Beliefs))
		npc.Beliefs = append(npc.Beliefs[:index], npc.Beliefs[index+1:]...)
		return
	}
	ids := make([]string, 0, len(facts))
	for id, fact := range facts {
		if fact.Discoverable && !known[id] && sharesAnyTopic(npc.Interests, fact.Topics) {
			ids = append(ids, id)
		}
	}
	sort.Strings(ids)
	if len(ids) > 0 {
		fact := facts[ids[rng.Intn(len(ids))]]
		npc.Beliefs = append(npc.Beliefs, domain.Belief{FactID: fact.ID, Claim: fact.Truth, Confidence: 1, EvidenceStrength: 1, Source: "sweep-observation"})
	}
}

func perturbBeliefList(rng *rand.Rand, beliefs []domain.Belief, amount int) {
	if amount == 0 {
		return
	}
	for i := range beliefs {
		beliefs[i].Confidence = clampRange(1, 3, beliefs[i].Confidence+delta(rng, amount))
		beliefs[i].EvidenceStrength = clampRange(1, 5, beliefs[i].EvidenceStrength+delta(rng, amount))
		beliefs[i].Source = fmt.Sprintf("%s|variant-%d", beliefs[i].Source, rng.Intn(amount*2+1))
		beliefs[i].Evidence = nil
	}
}

func sharesAnyTopic(left, right []string) bool {
	for _, a := range left {
		for _, b := range right {
			if a == b {
				return true
			}
		}
	}
	return false
}

func clampRange(minimum, maximum, value int) int {
	if value < minimum {
		return minimum
	}
	if value > maximum {
		return maximum
	}
	return value
}

func cloneBundle(source domain.Bundle) domain.Bundle {
	clone := source
	clone.Scenario.Topics = append([]string(nil), source.Scenario.Topics...)
	clone.Scenario.Phases = append([]domain.SituationPhase(nil), source.Scenario.Phases...)
	clone.Scenario.FixedEvents = append([]domain.FixedEvent(nil), source.Scenario.FixedEvents...)
	for i := range clone.Scenario.FixedEvents {
		clone.Scenario.FixedEvents[i].Effects = append([]domain.Effect(nil), source.Scenario.FixedEvents[i].Effects...)
	}
	clone.Scenario.Markets = append([]domain.MarketDefinition(nil), source.Scenario.Markets...)
	for i := range clone.Scenario.Markets {
		clone.Scenario.Markets[i].Stock = cloneIntMap(source.Scenario.Markets[i].Stock)
		clone.Scenario.Markets[i].BasePrices = cloneIntMap(source.Scenario.Markets[i].BasePrices)
	}
	clone.Items = make(map[string]domain.ItemDefinition, len(source.Items))
	for id, item := range source.Items {
		clone.Items[id] = item
	}
	clone.Locations = make(map[string]domain.Location, len(source.Locations))
	for id, location := range source.Locations {
		location.Routes = append([]domain.Route(nil), location.Routes...)
		clone.Locations[id] = location
	}
	clone.NPCs = append([]domain.NPCConfig(nil), source.NPCs...)
	clone.InitialRelations = append([]domain.Relation(nil), source.InitialRelations...)
	for i := range clone.NPCs {
		clone.NPCs[i].Resources = cloneIntMap(source.NPCs[i].Resources)
		clone.NPCs[i].Items = append([]string(nil), source.NPCs[i].Items...)
		clone.NPCs[i].Interests = append([]string(nil), source.NPCs[i].Interests...)
		clone.NPCs[i].Goals = append([]domain.Goal(nil), source.NPCs[i].Goals...)
		for j := range clone.NPCs[i].Goals {
			clone.NPCs[i].Goals[j].Topics = append([]string(nil), source.NPCs[i].Goals[j].Topics...)
		}
		clone.NPCs[i].Beliefs = append([]domain.Belief(nil), source.NPCs[i].Beliefs...)
		clone.NPCs[i].Strategies = cloneStrategies(source.NPCs[i].Strategies)
	}
	return clone
}

func clonePlans(source []domain.RunPlan) []domain.RunPlan {
	clone := append([]domain.RunPlan(nil), source...)
	for i := range clone {
		clone[i].Player.Resources = cloneIntMap(source[i].Player.Resources)
		clone[i].Player.Items = append([]string(nil), source[i].Player.Items...)
		clone[i].Player.Beliefs = append([]domain.Belief(nil), source[i].Player.Beliefs...)
		clone[i].Commands = append([]domain.PlayerCommand(nil), source[i].Commands...)
		for j := range clone[i].Commands {
			clone[i].Commands[j] = cloneCommand(source[i].Commands[j])
		}
	}
	return clone
}

func cloneStrategies(source []domain.Strategy) []domain.Strategy {
	clone := append([]domain.Strategy(nil), source...)
	for i := range clone {
		clone[i].Conditions = append([]domain.Condition(nil), source[i].Conditions...)
		clone[i].CompletionConditions = append([]domain.Condition(nil), source[i].CompletionConditions...)
		clone[i].Effects = append([]domain.Effect(nil), source[i].Effects...)
		clone[i].GoalTypes = append([]string(nil), source[i].GoalTypes...)
		clone[i].Costs = cloneIntMap(source[i].Costs)
	}
	return clone
}

func perturbResources(rng *rand.Rand, resources, floors map[string]int, amount int) {
	keys := make([]string, 0, len(resources))
	for key := range resources {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	for _, key := range keys {
		resources[key] = clampMin(floors[key], resources[key]+delta(rng, amount))
	}
}

func resourceFloorsForStrategies(actorID string, strategies []domain.Strategy) map[string]int {
	floors := make(map[string]int)
	for _, strategy := range strategies {
		for resource, amount := range strategy.Costs {
			floors[resource] += amount
		}
		addResourceFloors(floors, actorID, strategy.Effects)
	}
	return floors
}

func resourceFloorsForCommands(actorID string, commands []domain.PlayerCommand) map[string]int {
	floors := make(map[string]int)
	for _, command := range commands {
		addCommandResourceFloors(floors, actorID, command)
	}
	return floors
}

func addCommandResourceFloors(floors map[string]int, actorID string, command domain.PlayerCommand) {
	for resource, amount := range command.Costs {
		floors[resource] += amount
	}
	addResourceFloors(floors, actorID, command.Effects)
	if command.Fallback != nil {
		addCommandResourceFloors(floors, actorID, *command.Fallback)
	}
}

func cloneCommand(source domain.PlayerCommand) domain.PlayerCommand {
	clone := source
	clone.Conditions = append([]domain.Condition(nil), source.Conditions...)
	clone.CompletionConditions = append([]domain.Condition(nil), source.CompletionConditions...)
	clone.Effects = append([]domain.Effect(nil), source.Effects...)
	clone.Costs = cloneIntMap(source.Costs)
	if source.Fallback != nil {
		fallback := cloneCommand(*source.Fallback)
		clone.Fallback = &fallback
	}
	return clone
}

func addResourceFloors(floors map[string]int, actorID string, effects []domain.Effect) {
	for _, effect := range effects {
		if effect.Type != "adjust_resource" || effect.Amount >= 0 {
			continue
		}
		if effect.TargetID != "" && effect.TargetID != actorID {
			continue
		}
		floors[effect.Key] += -effect.Amount
	}
}

func delta(rng *rand.Rand, amount int) int {
	if amount == 0 {
		return 0
	}
	return rng.Intn(2*amount+1) - amount
}

func clampMin(minimum, value int) int {
	if value < minimum {
		return minimum
	}
	return value
}

func cloneIntMap(source map[string]int) map[string]int {
	clone := make(map[string]int, len(source))
	for key, value := range source {
		clone[key] = value
	}
	return clone
}

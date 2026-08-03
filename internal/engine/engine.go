package engine

import (
	"fmt"
	"sort"
	"strconv"
	"strings"

	"fantu/internal/domain"
)

type Engine struct {
	bundle domain.Bundle
	state  *domain.WorldState
	plan   *domain.RunPlan
	nextID int
}

func New(bundle domain.Bundle) *Engine {
	return newEngine(bundle, nil)
}

func NewWithPlan(bundle domain.Bundle, plan domain.RunPlan) *Engine {
	return newEngine(bundle, &plan)
}

func NewWithPlayer(bundle domain.Bundle, player domain.PlayerConfig) *Engine {
	plan := domain.RunPlan{ID: bundle.Scenario.ID, Title: bundle.Scenario.Title, Player: player}
	return newEngine(bundle, &plan)
}

func newEngine(bundle domain.Bundle, plan *domain.RunPlan) *Engine {
	state := &domain.WorldState{
		RunID: bundle.Scenario.ID, RunTitle: bundle.Scenario.Title,
		NPCs:               make(map[string]*domain.NPCState, len(bundle.NPCs)),
		Facts:              bundle.Facts,
		Items:              make(map[string]string, len(bundle.Items)),
		WorldFlags:         make(map[string]bool),
		ActorFlags:         make(map[string]map[string]bool),
		WorldFlagSources:   make(map[string]string),
		ActorFlagSources:   make(map[string]map[string]string),
		ItemSources:        make(map[string]string),
		Relations:          make(map[string]domain.Relation),
		Opportunities:      make(map[string]string),
		OpportunitySources: make(map[string]string),
		StoryStates:        make(map[string]string, len(bundle.StoryArcs)),
		Markets:            make(map[string]*domain.MarketState),
		Debts:              make(map[string]*domain.Debt),
		Alliances:          make(map[string]*domain.Alliance),
		Agreements:         make(map[string]*domain.Agreement),
		Director: domain.WorldDirectorState{
			Uses: make(map[string]int), LastUsedDay: make(map[string]int),
		},
	}
	for id, arc := range bundle.StoryArcs {
		state.StoryStates[id] = arc.InitialState
	}
	for _, market := range bundle.Scenario.Markets {
		state.Markets[market.ID] = &domain.MarketState{
			ID: market.ID, LocationID: market.LocationID, Currency: market.Currency, Stock: copyIntMap(market.Stock), Prices: copyIntMap(market.BasePrices),
			Sold: make(map[string]int), PriceStep: market.PriceStep, BlockadeFlag: market.BlockadeFlag,
		}
	}
	for id, item := range bundle.Items {
		state.Items[id] = item.Owner
	}
	for _, relation := range bundle.InitialRelations {
		state.Relations[domain.RelationKey(relation.From, relation.To)] = relation
	}
	for _, cfg := range bundle.NPCs {
		npc := &domain.NPCState{
			ID:          cfg.ID,
			Name:        cfg.Name,
			Faction:     cfg.Faction,
			Goal:        cfg.Goal,
			Goals:       append([]domain.Goal(nil), cfg.Goals...),
			Interests:   append([]string(nil), cfg.Interests...),
			Location:    cfg.Location,
			Injury:      cfg.Injury,
			Resources:   copyIntMap(cfg.Resources),
			Items:       make(map[string]int),
			Beliefs:     make(map[string]domain.Belief),
			Personality: cfg.Personality,
			Strategies:  cfg.Strategies,
			Completed:   make(map[string]bool),
			Plans:       make(map[string]*domain.PlanChain),
		}
		for _, item := range cfg.Items {
			npc.Items[item]++
		}
		for _, belief := range cfg.Beliefs {
			mergeBelief(npc.Beliefs, belief)
		}
		state.NPCs[npc.ID] = npc
	}
	if plan != nil {
		state.Player = newPlayerState(plan.Player)
		state.RunID = plan.ID
		state.RunTitle = plan.Title
	}
	return &Engine{bundle: bundle, state: state, plan: plan}
}

func (e *Engine) Run() (*domain.WorldState, error) {
	return e.RunUntil(e.bundle.Scenario.Duration)
}

func (e *Engine) RunUntil(targetDay int) (*domain.WorldState, error) {
	if targetDay < e.state.Day || targetDay > e.bundle.Scenario.Duration {
		return nil, fmt.Errorf("target day %d outside current range %d..%d", targetDay, e.state.Day, e.bundle.Scenario.Duration)
	}
	for e.state.Day < targetDay {
		if _, err := e.Step(nil); err != nil {
			return nil, err
		}
	}
	if targetDay == e.bundle.Scenario.Duration && e.state.Outcome == "" {
		e.state.Outcome = "事件窗口结束，但核心资源仍未产生明确归属"
	}
	return e.State(), nil

}

func (e *Engine) Step(commands []domain.PlayerCommand) (*domain.WorldState, error) {
	backup := cloneWorld(e.state)
	backupNextID := e.nextID
	state, err := e.step(commands)
	if err != nil {
		e.state = backup
		e.nextID = backupNextID
	}
	return state, err
}

func (e *Engine) step(commands []domain.PlayerCommand) (*domain.WorldState, error) {
	day := e.state.Day + 1
	if day > e.bundle.Scenario.Duration {
		return nil, fmt.Errorf("scenario already ended on day %d", e.state.Day)
	}
	if len(commands) > 0 && e.state.Player == nil {
		return nil, fmt.Errorf("cannot submit player commands without a player state")
	}
	e.state.Day = day
	e.state.Phase = phaseForDay(e.bundle.Scenario.Phases, day)
	if err := e.runFixedEvents(day, "start"); err != nil {
		return nil, err
	}
	if err := e.deliverInformation(day); err != nil {
		return nil, err
	}
	if err := e.runWorldDirector(); err != nil {
		return nil, err
	}

	snapshot := cloneWorld(e.state)
	intents := e.decide(snapshot)
	planned, err := e.playerIntents(day)
	if err != nil {
		return nil, err
	}
	intents = append(intents, planned...)
	external, err := e.commandsToIntents(day, commands)
	if err != nil {
		return nil, err
	}
	intents = append(intents, external...)
	if err := e.startIntents(intents); err != nil {
		return nil, err
	}
	if err := e.completeDueActions(day); err != nil {
		return nil, err
	}

	if err := e.runFixedEvents(day, "end"); err != nil {
		return nil, err
	}
	if day == e.bundle.Scenario.Contest.Day {
		if err := e.resolveContest(); err != nil {
			return nil, err
		}
	}
	e.processDebtDeadlines(day)
	if err := ValidateState(e.state, e.bundle); err != nil {
		return nil, fmt.Errorf("day %d: %w", day, err)
	}
	return e.State(), nil
}

func (e *Engine) State() *domain.WorldState {
	return cloneWorld(e.state)
}

// Interrupt stops an actor's pending action between simulation steps and
// records an auditable event. It is intended for external systems such as
// combat, dialogue, or player control to cancel work already in progress.
func (e *Engine) Interrupt(actorID, reason string) (*domain.WorldState, error) {
	pending, err := e.pendingFor(actorID)
	if err != nil {
		return nil, err
	}
	if pending == nil {
		return nil, fmt.Errorf("actor %s has no pending action", actorID)
	}
	if reason == "" {
		reason = "外部事件中断行动"
	}
	event := e.newEvent("action_interrupted", actorID, pending.Intent.TargetID, reason, pending.Intent.ID, nil)
	tagActionEvent(&event, pending.Intent)
	event.ParentEventID = pending.StartEventID
	e.refundCosts(actorID, pending.PaidCosts)
	e.clearPending(actorID)
	e.failPlan(actorID, pending.Intent.Strategy.PlanID)
	e.state.Events = append(e.state.Events, event)
	return e.State(), nil
}

func (e *Engine) decide(snapshot *domain.WorldState) []domain.ActionIntent {
	ids := make([]string, 0, len(snapshot.NPCs))
	for id := range snapshot.NPCs {
		ids = append(ids, id)
	}
	sort.Strings(ids)

	var intents []domain.ActionIntent
	for _, id := range ids {
		npc := snapshot.NPCs[id]
		if npc.Pending != nil {
			continue
		}
		strategies := npc.Strategies
		if e.bundle.Scenario.PlanningMode == "unified_score" {
			strategies = append(append([]domain.Strategy(nil), strategies...), e.genericStrategies(snapshot, npc)...)
		}
		choices := e.rankChoices(snapshot, npc, strategies)
		if len(choices) == 0 && e.bundle.Scenario.PlanningMode != "unified_score" {
			strategies = e.genericStrategies(snapshot, npc)
			choices = e.rankChoices(snapshot, npc, strategies)
		}
		if len(choices) == 0 {
			continue
		}
		if len(choices) > 3 {
			choices = choices[:3]
		}
		record := domain.DecisionRecord{
			Day: day(snapshot), ActorID: npc.ID, ActorName: npc.Name, Choices: choices,
		}
		selected := choices[0]
		e.auditDecision(snapshot, npc.ID, strategies, selected.StrategyID, &record)
		e.state.Decisions = append(e.state.Decisions, record)
		strategy := findStrategy(strategies, selected.StrategyID)
		e.attachPlan(npc.ID, &strategy)
		intents = append(intents, domain.ActionIntent{
			ID:  fmt.Sprintf("intent-%02d-%s", snapshot.Day, npc.ID),
			Day: snapshot.Day, ActorID: npc.ID, TargetID: strategy.TargetID,
			Action: e.bundle.Actions[strategy.ActionID], Strategy: strategy, Score: selected.Score,
			TriggerEventIDs: collectTriggerEvents(snapshot, npc.ID, npc.Beliefs, strategy.Conditions),
		})
	}
	return intents
}

func day(state *domain.WorldState) int { return state.Day }

func (e *Engine) rankChoices(state *domain.WorldState, npc *domain.NPCState, strategies []domain.Strategy) []domain.RankedChoice {
	var choices []domain.RankedChoice
	for _, strategy := range strategies {
		if strategy.Once && npc.Completed[strategy.ID] {
			continue
		}
		if state.Day < strategy.FromDay || (strategy.UntilDay > 0 && state.Day > strategy.UntilDay) {
			continue
		}
		if !conditionsMet(state, npc, strategy.Conditions) {
			continue
		}
		duration := strategy.Duration
		if duration <= 0 {
			duration = e.bundle.Actions[strategy.ActionID].Duration
		}
		if duration <= 0 {
			duration = 1
		}
		if state.Day+duration-1 > e.bundle.Scenario.Duration {
			continue
		}
		if ok, _ := e.movementEffectsLegal(strategy.Effects, npc.ID, duration); !ok {
			continue
		}
		if ok, _ := e.uniqueTransfersLegal(strategy.Effects); !ok {
			continue
		}
		if ok, _ := e.marketPurchasesLegal(strategy.Effects, npc.ID, strategy.Costs); !ok {
			continue
		}
		if ok, _ := e.canAfford(npc.ID, strategy.Costs); !ok {
			continue
		}
		scoreInput := strategy.Score
		scoreInput.Goal += goalAlignment(npc.Goals, strategy.GoalTypes)
		score := calculateScore(npc.Personality, scoreInput, relationshipModifier(state, npc.ID, strategy.TargetID))
		choices = append(choices, domain.RankedChoice{
			StrategyID: strategy.ID, ActionID: strategy.ActionID,
			Description: strategy.Description, Score: score, Generated: strategy.Generated,
		})
	}
	sort.SliceStable(choices, func(i, j int) bool {
		if choices[i].Score.Total != choices[j].Score.Total {
			return choices[i].Score.Total > choices[j].Score.Total
		}
		left, right := findStrategy(strategies, choices[i].StrategyID), findStrategy(strategies, choices[j].StrategyID)
		leftDuration := e.bundle.Actions[left.ActionID].Duration
		rightDuration := e.bundle.Actions[right.ActionID].Duration
		if leftDuration != rightDuration {
			return leftDuration < rightDuration
		}
		if choices[i].Score.Danger != choices[j].Score.Danger {
			return choices[i].Score.Danger < choices[j].Score.Danger
		}
		return choices[i].StrategyID < choices[j].StrategyID
	})
	return choices
}

func goalAlignment(goals []domain.Goal, types []string) int {
	best := 0
	for _, goalType := range types {
		for _, goal := range goals {
			if goal.Type == goalType && goal.Priority > best {
				best = goal.Priority
			}
		}
	}
	return best
}

func (e *Engine) startIntents(intents []domain.ActionIntent) error {
	seen := make(map[string]bool)
	for _, intent := range intents {
		if seen[intent.ActorID] {
			return fmt.Errorf("actor %s submitted more than one action on day %d", intent.ActorID, e.state.Day)
		}
		seen[intent.ActorID] = true
		duration := intent.Strategy.Duration
		if duration <= 0 {
			duration = intent.Action.Duration
		}
		if duration <= 0 {
			duration = 1
		}
		if ok, reason := e.movementEffectsLegal(intent.Strategy.Effects, intent.ActorID, duration); !ok {
			if intent.Player {
				return fmt.Errorf("player command %s has illegal movement: %s", intent.ID, reason)
			}
			continue
		}
		if ok, reason := e.uniqueTransfersLegal(intent.Strategy.Effects); !ok {
			if intent.Player {
				return fmt.Errorf("player command %s has invalid unique transfer: %s", intent.ID, reason)
			}
			continue
		}
		if ok, reason := e.marketPurchasesLegal(intent.Strategy.Effects, intent.ActorID, intent.Strategy.Costs); !ok {
			if intent.Player {
				return fmt.Errorf("player command %s has invalid market purchase: %s", intent.ID, reason)
			}
			continue
		}
		if ok, reason := e.canAfford(intent.ActorID, intent.Strategy.Costs); !ok {
			if intent.Player {
				return fmt.Errorf("player command %s cannot pay costs: %s", intent.ID, reason)
			}
			continue
		}
		pending := &domain.PendingAction{Intent: intent, StartedDay: e.state.Day, CompleteDay: e.state.Day + duration - 1}
		if intent.Player {
			if e.state.Player == nil {
				return fmt.Errorf("player action %s has no player state", intent.ID)
			}
			if e.state.Player.Pending != nil {
				return fmt.Errorf("player is busy with %s until day %d", e.state.Player.Pending.Intent.ID, e.state.Player.Pending.CompleteDay)
			}
			if !playerConditionsMet(e.state, e.state.Player, intent.Strategy.Conditions) {
				return fmt.Errorf("player command %s does not meet its conditions on day %d", intent.ID, e.state.Day)
			}
			pending.PaidCosts = e.payCosts(intent.ActorID, intent.Strategy.Costs)
			e.state.Player.Pending = pending
		} else {
			actor, err := e.state.NPC(intent.ActorID)
			if err != nil {
				return err
			}
			if actor.Pending != nil || !conditionsMet(e.state, actor, intent.Strategy.Conditions) {
				continue
			}
			pending.PaidCosts = e.payCosts(intent.ActorID, intent.Strategy.Costs)
			actor.Pending = pending
		}
		if duration > 1 {
			event := e.newEvent("action_start", intent.ActorID, intent.TargetID, "开始："+intent.Strategy.Description, intent.ID, nil)
			tagActionEvent(&event, intent)
			pending.StartEventID = event.ID
			e.state.Events = append(e.state.Events, event)
		}
	}
	return nil
}

func (e *Engine) completeDueActions(day int) error {
	var intents []domain.ActionIntent
	if e.state.Player != nil && e.state.Player.Pending != nil && e.state.Player.Pending.CompleteDay == day {
		intents = append(intents, e.state.Player.Pending.Intent)
	}
	for _, npc := range e.state.NPCs {
		if npc.Pending != nil && npc.Pending.CompleteDay == day {
			intents = append(intents, npc.Pending.Intent)
		}
	}
	sort.SliceStable(intents, func(i, j int) bool {
		if intents[i].Action.Phase != intents[j].Action.Phase {
			return intents[i].Action.Phase < intents[j].Action.Phase
		}
		return intents[i].ActorID < intents[j].ActorID
	})
	claimLosers := e.resolveUniqueClaimConflicts(intents)
	marketLosers := e.resolveMarketPurchaseConflicts(intents)
	for _, intent := range intents {
		pending, err := e.pendingFor(intent.ActorID)
		if err != nil {
			return err
		}
		if itemID, lost := claimLosers[intent.ActorID]; lost {
			e.refundCosts(intent.ActorID, pending.PaidCosts)
			e.clearPending(intent.ActorID)
			event := e.newEvent("action_failed", intent.ActorID, intent.TargetID, "同日唯一物品竞争失败："+itemID, intent.ID, nil)
			tagActionEvent(&event, intent)
			event.ParentEventID = pending.StartEventID
			e.state.Events = append(e.state.Events, event)
			e.failPlan(intent.ActorID, intent.Strategy.PlanID)
			continue
		}
		if reason, lost := marketLosers[intent.ActorID]; lost {
			e.refundCosts(intent.ActorID, pending.PaidCosts)
			e.clearPending(intent.ActorID)
			event := e.newEvent("action_failed", intent.ActorID, intent.TargetID, "同日市场库存竞争失败："+reason, intent.ID, nil)
			tagActionEvent(&event, intent)
			event.ParentEventID = pending.StartEventID
			e.state.Events = append(e.state.Events, event)
			e.failPlan(intent.ActorID, intent.Strategy.PlanID)
			continue
		}
		legal, reason, err := e.intentCompletionLegal(intent)
		if err != nil {
			return err
		}
		if !legal {
			e.refundCosts(intent.ActorID, pending.PaidCosts)
			e.clearPending(intent.ActorID)
			event := e.newEvent("action_failed", intent.ActorID, intent.TargetID, "行动完成失败："+intent.Strategy.Description+"（"+reason+"）", intent.ID, nil)
			event.ActionID = intent.Action.ID
			tagActionEvent(&event, intent)
			event.ParentEventID = pending.StartEventID
			e.state.Events = append(e.state.Events, event)
			e.failPlan(intent.ActorID, intent.Strategy.PlanID)
			continue
		}
		if intent.Player {
			reportedEffects := append(costEffects(pending.PaidCosts), intent.Strategy.Effects...)
			event := e.newEvent("player_action", intent.ActorID, intent.TargetID, intent.Strategy.Description, intent.ID, reportedEffects)
			event.ActionID = intent.Action.ID
			tagActionEvent(&event, intent)
			event.ParentEventID = pending.StartEventID
			if err := e.applyEffects(event, intent.Strategy.Effects, intent.ActorID); err != nil {
				return fmt.Errorf("resolve player command %s: %w", intent.ID, err)
			}
			e.state.Player.Pending = nil
			e.state.Events = append(e.state.Events, event)
			continue
		}
		actor, err := e.state.NPC(intent.ActorID)
		if err != nil {
			return err
		}
		reportedEffects := append(costEffects(pending.PaidCosts), intent.Strategy.Effects...)
		event := e.newEvent("action", intent.ActorID, intent.TargetID, intent.Strategy.Description, intent.ID, reportedEffects)
		event.ActionID = intent.Action.ID
		tagActionEvent(&event, intent)
		event.ParentEventID = pending.StartEventID
		if err := e.applyEffects(event, intent.Strategy.Effects, intent.ActorID); err != nil {
			return fmt.Errorf("resolve %s for %s: %w", intent.Strategy.ID, intent.ActorID, err)
		}
		actor.Completed[intent.Strategy.ID] = intent.Strategy.Once
		actor.Pending = nil
		e.completePlanStep(intent.ActorID, intent.Strategy.PlanID, intent.Strategy.PlanStepID)
		e.state.Events = append(e.state.Events, event)
	}
	return nil
}

func (e *Engine) pendingFor(actorID string) (*domain.PendingAction, error) {
	if e.state.Player != nil && e.state.Player.ID == actorID {
		return e.state.Player.Pending, nil
	}
	npc, ok := e.state.NPCs[actorID]
	if !ok {
		return nil, fmt.Errorf("unknown actor %s", actorID)
	}
	return npc.Pending, nil
}

func (e *Engine) clearPending(actorID string) {
	if e.state.Player != nil && e.state.Player.ID == actorID {
		e.state.Player.Pending = nil
		return
	}
	if npc, ok := e.state.NPCs[actorID]; ok {
		npc.Pending = nil
	}
}

func (e *Engine) intentCompletionLegal(intent domain.ActionIntent) (bool, string, error) {
	if intent.Player {
		if e.state.Player == nil {
			return false, "玩家状态不存在", nil
		}
		if !playerConditionsMet(e.state, e.state.Player, completionConditions(intent.Strategy)) {
			return false, "行动条件已经变化", nil
		}
	} else {
		npc, err := e.state.NPC(intent.ActorID)
		if err != nil {
			return false, "", err
		}
		if !conditionsMet(e.state, npc, completionConditions(intent.Strategy)) {
			return false, "行动条件已经变化", nil
		}
	}
	duration := intent.Strategy.Duration
	if duration <= 0 {
		duration = intent.Action.Duration
	}
	if duration <= 0 {
		duration = 1
	}
	if ok, reason := e.movementEffectsLegal(intent.Strategy.Effects, intent.ActorID, duration); !ok {
		return false, reason, nil
	}
	if ok, reason := e.uniqueTransfersLegal(intent.Strategy.Effects); !ok {
		return false, reason, nil
	}
	if ok, reason := e.marketPurchasesLegal(intent.Strategy.Effects, intent.ActorID, intent.Strategy.Costs); !ok {
		return false, reason, nil
	}
	return true, "", nil
}

func tagActionEvent(event *domain.WorldEvent, intent domain.ActionIntent) {
	event.ActionID = intent.Action.ID
	event.StrategyID = intent.Strategy.ID
	event.IntentID = intent.ID
	event.TriggerEventIDs = append([]string(nil), intent.TriggerEventIDs...)
	event.PlanID = intent.Strategy.PlanID
	event.PlanStepID = intent.Strategy.PlanStepID
	event.Conditions = append([]domain.Condition(nil), intent.Strategy.Conditions...)
}

func completionConditions(strategy domain.Strategy) []domain.Condition {
	if len(strategy.CompletionConditions) > 0 {
		return strategy.CompletionConditions
	}
	conditions := make([]domain.Condition, 0, len(strategy.Conditions))
	for _, condition := range strategy.Conditions {
		switch condition.Type {
		case "resource_at_least", "resource_at_most":
			continue
		default:
			conditions = append(conditions, condition)
		}
	}
	return conditions
}

func (e *Engine) playerIntents(day int) ([]domain.ActionIntent, error) {
	if e.plan == nil {
		return nil, nil
	}
	var intents []domain.ActionIntent
	for _, command := range e.plan.Commands {
		if command.Day != day {
			continue
		}
		resolved, err := e.resolvePlannedCommand(day, command, 0)
		if err != nil {
			return nil, err
		}
		intents = append(intents, resolved...)
	}
	return intents, nil
}

func (e *Engine) resolvePlannedCommand(day int, command domain.PlayerCommand, depth int) ([]domain.ActionIntent, error) {
	if depth > 8 {
		return nil, fmt.Errorf("player command %s fallback nesting exceeds 8 levels", command.ID)
	}
	if playerConditionsMet(e.state, e.state.Player, command.Conditions) {
		return e.commandsToIntents(day, []domain.PlayerCommand{command})
	}
	switch command.OnFailure {
	case "skip":
		e.recordSkippedCommand(command, "前置条件不满足，按计划跳过")
		return nil, nil
	case "fallback":
		if command.Fallback == nil {
			return nil, fmt.Errorf("player command %s has no fallback", command.ID)
		}
		e.recordSkippedCommand(command, "前置条件不满足，改用替代命令 "+command.Fallback.ID)
		return e.resolvePlannedCommand(day, *command.Fallback, depth+1)
	case "", "error":
		return nil, fmt.Errorf("player command %s does not meet its conditions on day %d", command.ID, day)
	default:
		return nil, fmt.Errorf("player command %s has unknown failure policy %q", command.ID, command.OnFailure)
	}
}

func (e *Engine) recordSkippedCommand(command domain.PlayerCommand, description string) {
	event := e.newEvent("player_command_skipped", e.state.Player.ID, command.TargetID, description, command.ID, nil)
	event.ActionID = command.ActionID
	event.StrategyID = command.ID
	event.IntentID = command.ID
	e.state.Events = append(e.state.Events, event)
}

func (e *Engine) commandsToIntents(day int, commands []domain.PlayerCommand) ([]domain.ActionIntent, error) {
	if len(commands) == 0 {
		return nil, nil
	}
	actorID := e.state.Player.ID
	intents := make([]domain.ActionIntent, 0, len(commands))
	for _, command := range commands {
		if command.Day != 0 && command.Day != day {
			return nil, fmt.Errorf("command %s targets day %d, current day is %d", command.ID, command.Day, day)
		}
		action, ok := e.bundle.Actions[command.ActionID]
		if !ok {
			return nil, fmt.Errorf("command %s references unknown action %s", command.ID, command.ActionID)
		}
		intents = append(intents, domain.ActionIntent{
			ID: command.ID, Day: day, ActorID: actorID, TargetID: command.TargetID,
			Action: action, Player: true,
			TriggerEventIDs: collectTriggerEvents(e.state, actorID, e.state.Player.Beliefs, command.Conditions),
			Strategy: domain.Strategy{
				ID: command.ID, ActionID: command.ActionID, TargetID: command.TargetID,
				Description: command.Description, Duration: command.Duration,
				Conditions: command.Conditions, CompletionConditions: command.CompletionConditions,
				Effects: command.Effects, Costs: command.Costs,
			},
		})
	}
	return intents, nil
}

func (e *Engine) runFixedEvents(day int, timing string) error {
	for _, fixed := range e.bundle.Scenario.FixedEvents {
		if fixed.Day != day || fixed.Timing != timing {
			continue
		}
		event := e.newEvent("fixed", "world", "", fixed.Description, fixed.ID, fixed.Effects)
		if err := e.applyEffects(event, fixed.Effects, "world"); err != nil {
			return fmt.Errorf("fixed event %s: %w", fixed.ID, err)
		}
		e.state.Events = append(e.state.Events, event)
	}
	return nil
}

func (e *Engine) resolveContest() error {
	contest := e.bundle.Scenario.Contest
	if owner := e.state.Items[contest.ItemID]; owner != contest.LocationID && owner != "" {
		if e.state.Outcome == "" {
			e.state.Outcome = renderContestText(contest.EarlyOutcome, displayName(e.state, owner), 0)
		}
		cancelled := strings.ReplaceAll(contest.CancelledOutcome, "{outcome}", e.state.Outcome)
		e.state.Events = append(e.state.Events, e.newEvent("contest", owner, contest.ItemID, cancelled, "contest", nil))
		return nil
	}
	type candidate struct {
		id    string
		score int
	}
	var candidates []candidate
	for id, npc := range e.state.NPCs {
		if npc.Location != contest.LocationID || npc.Injury >= 3 {
			continue
		}
		if contest.RequiredItemID != "" && npc.Items[contest.RequiredItemID] <= 0 {
			continue
		}
		score := -npc.Injury
		for _, resource := range contest.ScoreResources {
			score += npc.Resources[resource]
		}
		if contest.PreparationFlag != "" && e.state.ActorFlag(id, contest.PreparationFlag) {
			score++
		}
		candidates = append(candidates, candidate{id: id, score: score})
	}
	if player := e.state.Player; player != nil && player.Location == contest.LocationID {
		if contest.RequiredItemID == "" || player.Items[contest.RequiredItemID] > 0 {
			score := 0
			for _, resource := range contest.ScoreResources {
				score += player.Resources[resource]
			}
			if contest.PreparationFlag != "" && e.state.ActorFlag(player.ID, contest.PreparationFlag) {
				score++
			}
			candidates = append(candidates, candidate{id: player.ID, score: score})
		}
	}
	sort.Slice(candidates, func(i, j int) bool {
		if candidates[i].score != candidates[j].score {
			return candidates[i].score > candidates[j].score
		}
		return candidates[i].id < candidates[j].id
	})
	if len(candidates) == 0 {
		e.state.Outcome = contest.NoWinnerOutcome
		e.state.Events = append(e.state.Events, e.newEvent("contest", "world", "", e.state.Outcome, "contest", nil))
		return nil
	}
	winner := candidates[0]
	e.state.Items[contest.ItemID] = winner.id
	if e.isPlayer(winner.id) {
		e.state.Player.Items[contest.ItemID]++
	} else {
		e.state.NPCs[winner.id].Items[contest.ItemID]++
	}
	e.state.Outcome = e.contestOutcome(contest, winner.id, winner.score)
	effects := []domain.Effect{{Type: "transfer_unique", TargetID: winner.id, Key: contest.ItemID}}
	event := e.newEvent("contest", winner.id, contest.ItemID, e.state.Outcome, "contest", effects)
	for _, rule := range sortedContestRules(contest.RewardRules) {
		if !e.contestRuleMatches(rule, winner.id) {
			continue
		}
		rewardEffects := e.materializeContestEffects(rule.Effects, winner.id)
		if err := e.applyEffects(event, rewardEffects, winner.id); err != nil {
			return fmt.Errorf("apply contest reward %s: %w", rule.ID, err)
		}
		effects = append(effects, rewardEffects...)
		e.state.Outcome += renderContestText(rule.Suffix, displayName(e.state, winner.id), winner.score)
	}
	event.Description = e.state.Outcome
	event.Effects = effects
	e.state.Events = append(e.state.Events, event)
	return nil
}

func (e *Engine) contestOutcome(contest domain.Contest, winnerID string, score int) string {
	template := contest.DefaultOutcome
	for _, rule := range sortedContestRules(contest.OutcomeRules) {
		if e.contestRuleMatches(rule, winnerID) {
			template = rule.Template
			break
		}
	}
	return renderContestText(template, displayName(e.state, winnerID), score)
}

func (e *Engine) contestRuleMatches(rule domain.ContestOutcomeRule, winnerID string) bool {
	if rule.WinnerID != "" && rule.WinnerID != winnerID {
		return false
	}
	for _, flag := range rule.RequiredWorldFlags {
		if !e.state.WorldFlag(flag) {
			return false
		}
	}
	if len(rule.RequiredPlayerFlags) > 0 || rule.MinWinnerTrust > 0 {
		if e.state.Player == nil {
			return false
		}
		for _, flag := range rule.RequiredPlayerFlags {
			if !e.state.ActorFlag(e.state.Player.ID, flag) {
				return false
			}
		}
		if e.state.RelationBetween(winnerID, e.state.Player.ID).Trust < rule.MinWinnerTrust {
			return false
		}
	}
	return true
}

func (e *Engine) materializeContestEffects(source []domain.Effect, winnerID string) []domain.Effect {
	effects := append([]domain.Effect(nil), source...)
	for index := range effects {
		if effects[index].TargetID == "player" && e.state.Player != nil {
			effects[index].TargetID = e.state.Player.ID
		} else if effects[index].TargetID == "winner" {
			effects[index].TargetID = winnerID
		}
		if effects[index].FromID == "player" && e.state.Player != nil {
			effects[index].FromID = e.state.Player.ID
		} else if effects[index].FromID == "winner" {
			effects[index].FromID = winnerID
		}
	}
	return effects
}

func sortedContestRules(source []domain.ContestOutcomeRule) []domain.ContestOutcomeRule {
	rules := append([]domain.ContestOutcomeRule(nil), source...)
	sort.Slice(rules, func(i, j int) bool {
		if rules[i].Priority != rules[j].Priority {
			return rules[i].Priority > rules[j].Priority
		}
		return rules[i].ID < rules[j].ID
	})
	return rules
}

func renderContestText(template, winnerName string, score int) string {
	result := strings.ReplaceAll(template, "{winner}", winnerName)
	return strings.ReplaceAll(result, "{score}", strconv.Itoa(score))
}

func (e *Engine) newEvent(kind, actor, target, description, cause string, effects []domain.Effect) domain.WorldEvent {
	e.nextID++
	return domain.WorldEvent{
		ID: fmt.Sprintf("event-%04d", e.nextID), Day: e.state.Day, Type: kind,
		ActorID: actor, TargetID: target, Description: description, CauseID: cause, Effects: effects,
	}
}

func phaseForDay(phases []domain.SituationPhase, day int) string {
	for _, phase := range phases {
		if day >= phase.FromDay && day <= phase.ToDay {
			return phase.Name
		}
	}
	return "未定义"
}

func findStrategy(strategies []domain.Strategy, id string) domain.Strategy {
	for _, strategy := range strategies {
		if strategy.ID == id {
			return strategy
		}
	}
	return domain.Strategy{}
}

func displayName(state *domain.WorldState, id string) string {
	if state.Player != nil && state.Player.ID == id {
		return state.Player.Name
	}
	if npc, ok := state.NPCs[id]; ok {
		return npc.Name
	}
	return id
}

func copyIntMap(source map[string]int) map[string]int {
	result := make(map[string]int, len(source))
	for key, value := range source {
		result[key] = value
	}
	return result
}

func newPlayerState(cfg domain.PlayerConfig) *domain.PlayerState {
	player := &domain.PlayerState{
		ID: cfg.ID, Name: cfg.Name, Location: cfg.Location, Injury: cfg.Injury,
		Resources: copyIntMap(cfg.Resources), Items: make(map[string]int), Beliefs: make(map[string]domain.Belief),
	}
	for _, item := range cfg.Items {
		player.Items[item]++
	}
	for _, belief := range cfg.Beliefs {
		mergeBelief(player.Beliefs, belief)
	}
	return player
}

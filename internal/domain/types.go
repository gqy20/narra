package domain

import "fmt"

type ResolutionPhase int

const (
	PhaseInformation ResolutionPhase = 10
	PhaseSocial      ResolutionPhase = 20
	PhaseMovement    ResolutionPhase = 30
	PhaseConflict    ResolutionPhase = 40
	PhaseRecovery    ResolutionPhase = 50
)

type Scenario struct {
	ID            string                        `json:"id"`
	Title         string                        `json:"title"`
	Duration      int                           `json:"duration"`
	PlanningMode  string                        `json:"planning_mode,omitempty"`
	Topics        []string                      `json:"topics,omitempty"`
	Markets       []MarketDefinition            `json:"markets,omitempty"`
	Directives    []WorldDirectiveDefinition    `json:"directives,omitempty"`
	Opportunities []OpportunityActionDefinition `json:"opportunity_actions,omitempty"`
	Phases        []SituationPhase              `json:"phases"`
	FixedEvents   []FixedEvent                  `json:"fixed_events"`
	Contest       Contest                       `json:"contest"`
}

type StoryArc struct {
	ID               string                 `json:"id"`
	Title            string                 `json:"title"`
	InitialState     string                 `json:"initial_state"`
	States           []string               `json:"states"`
	Nodes            []StoryNode            `json:"nodes"`
	ProgressRules    []StoryProgressRule    `json:"progress_rules,omitempty"`
	ConsequenceRules []StoryConsequenceRule `json:"consequence_rules,omitempty"`
}

type StoryConsequenceRule struct {
	ID             string      `json:"id"`
	States         []string    `json:"states"`
	Conditions     []Condition `json:"conditions,omitempty"`
	Text           string      `json:"text"`
	RelationFromID string      `json:"relation_from_id,omitempty"`
	RelationToID   string      `json:"relation_to_id,omitempty"`
	RelationMetric string      `json:"relation_metric,omitempty"`
}

type StoryProgressRule struct {
	ID             string      `json:"id"`
	Priority       int         `json:"priority"`
	FromDay        int         `json:"from_day,omitempty"`
	UntilDay       int         `json:"until_day,omitempty"`
	Conditions     []Condition `json:"conditions"`
	RouteID        string      `json:"route_id"`
	Label          string      `json:"label"`
	Status         string      `json:"status"`
	NextStep       string      `json:"next_step"`
	Window         string      `json:"window,omitempty"`
	DeadlineDay    int         `json:"deadline_day,omitempty"`
	LocationID     string      `json:"location_id,omitempty"`
	PersonalReturn string      `json:"personal_return,omitempty"`
	Urgent         bool        `json:"urgent,omitempty"`
	Complete       bool        `json:"complete,omitempty"`
}

type StoryNode struct {
	ID                   string        `json:"id"`
	FromState            string        `json:"from_state"`
	FromDay              int           `json:"from_day,omitempty"`
	UntilDay             int           `json:"until_day,omitempty"`
	LocationID           string        `json:"location_id,omitempty"`
	TargetID             string        `json:"target_id"`
	AllowRemoteTarget    bool          `json:"allow_remote_target,omitempty"`
	FactID               string        `json:"fact_id"`
	MinConfidence        int           `json:"min_confidence"`
	ActionID             string        `json:"action_id"`
	Kind                 string        `json:"kind,omitempty"`
	Category             string        `json:"category,omitempty"`
	Conditions           []Condition   `json:"conditions,omitempty"`
	CompletionConditions []Condition   `json:"completion_conditions,omitempty"`
	Choices              []StoryChoice `json:"choices"`
}

type StoryChoice struct {
	ID                 string        `json:"id"`
	TermID             string        `json:"term_id"`
	TermLabel          string        `json:"term_label"`
	Name               string        `json:"name"`
	Description        string        `json:"description"`
	CommandDescription string        `json:"command_description,omitempty"`
	PersonalOutcome    string        `json:"personal_outcome"`
	Relevance          string        `json:"relevance,omitempty"`
	Risk               string        `json:"risk,omitempty"`
	ExpectedOutcomes   []string      `json:"expected_outcomes,omitempty"`
	Resolves           []string      `json:"resolves,omitempty"`
	Warnings           []string      `json:"warnings,omitempty"`
	Irreversible       bool          `json:"irreversible,omitempty"`
	Conditions         []Condition   `json:"conditions,omitempty"`
	Effects            []Effect      `json:"effects"`
	ToState            string        `json:"to_state"`
	Feedback           StoryFeedback `json:"feedback"`
}

type StoryFeedback struct {
	Messages     []string          `json:"messages"`
	Journal      []string          `json:"journal,omitempty"`
	Presentation StoryPresentation `json:"presentation"`
}

type StoryPresentation struct {
	Kind      string `json:"kind"`
	Intensity int    `json:"intensity"`
	Subject   string `json:"subject,omitempty"`
}

type FlagDefinition struct {
	ID          string `json:"id"`
	Scope       string `json:"scope"`
	Description string `json:"description"`
	PublicLabel string `json:"public_label,omitempty"`
}

// OpportunityActionDefinition maps an open world opportunity to a normal
// authoritative player action. The world director may open the opportunity,
// but only the player can choose whether to execute its effects.
type OpportunityActionDefinition struct {
	ID          string         `json:"id"`
	Key         string         `json:"key"`
	ActionID    string         `json:"action_id"`
	Name        string         `json:"name"`
	Description string         `json:"description"`
	LocationID  string         `json:"location_id"`
	Duration    int            `json:"duration,omitempty"`
	Costs       map[string]int `json:"costs,omitempty"`
	Effects     []Effect       `json:"effects"`
}

// WorldDirectiveDefinition is a scenario-authored capability that the world
// director may select. The director can only choose these definitions; the
// engine remains responsible for validating and applying their effects.
type WorldDirectiveDefinition struct {
	ID           string   `json:"id"`
	Description  string   `json:"description"`
	Trigger      string   `json:"trigger"`
	TargetID     string   `json:"target_id,omitempty"`
	Key          string   `json:"key,omitempty"`
	Phase        string   `json:"phase,omitempty"`
	FromDay      int      `json:"from_day,omitempty"`
	UntilDay     int      `json:"until_day,omitempty"`
	MinValue     int      `json:"min_value,omitempty"`
	MinQuietDays int      `json:"min_quiet_days,omitempty"`
	Priority     int      `json:"priority"`
	CooldownDays int      `json:"cooldown_days,omitempty"`
	MaxUses      int      `json:"max_uses,omitempty"`
	Effects      []Effect `json:"effects"`
}

type MarketDefinition struct {
	ID           string         `json:"id"`
	LocationID   string         `json:"location_id"`
	Stock        map[string]int `json:"stock"`
	BasePrices   map[string]int `json:"base_prices"`
	PriceStep    int            `json:"price_step"`
	BlockadeFlag string         `json:"blockade_flag,omitempty"`
}

type MarketState struct {
	ID           string
	LocationID   string
	Stock        map[string]int
	Prices       map[string]int
	Sold         map[string]int
	PriceStep    int
	BlockadeFlag string
}

type SituationPhase struct {
	ID      string `json:"id"`
	Name    string `json:"name"`
	FromDay int    `json:"from_day"`
	ToDay   int    `json:"to_day"`
}

type FixedEvent struct {
	ID          string   `json:"id"`
	Day         int      `json:"day"`
	Timing      string   `json:"timing"`
	Description string   `json:"description"`
	Effects     []Effect `json:"effects"`
}

type Contest struct {
	Day              int                  `json:"day"`
	ItemID           string               `json:"item_id"`
	LocationID       string               `json:"location_id"`
	RequiredItemID   string               `json:"required_item_id"`
	ScoreResources   []string             `json:"score_resources"`
	PreparationFlag  string               `json:"preparation_flag"`
	EarlyOutcome     string               `json:"early_outcome"`
	CancelledOutcome string               `json:"cancelled_outcome"`
	NoWinnerOutcome  string               `json:"no_winner_outcome"`
	DefaultOutcome   string               `json:"default_outcome"`
	OutcomeRules     []ContestOutcomeRule `json:"outcome_rules,omitempty"`
	RewardRules      []ContestOutcomeRule `json:"reward_rules,omitempty"`
}

type ContestOutcomeRule struct {
	ID                  string   `json:"id"`
	Priority            int      `json:"priority"`
	WinnerID            string   `json:"winner_id,omitempty"`
	RequiredWorldFlags  []string `json:"required_world_flags,omitempty"`
	RequiredPlayerFlags []string `json:"required_player_flags,omitempty"`
	MinWinnerTrust      int      `json:"min_winner_trust,omitempty"`
	Template            string   `json:"template,omitempty"`
	Suffix              string   `json:"suffix,omitempty"`
	Effects             []Effect `json:"effects,omitempty"`
}

type ActionDefinition struct {
	ID       string          `json:"id"`
	Name     string          `json:"name"`
	Phase    ResolutionPhase `json:"phase"`
	Duration int             `json:"duration"`
}

type Fact struct {
	ID           string     `json:"id"`
	Truth        string     `json:"truth"`
	Discoverable bool       `json:"discoverable"`
	Topics       []string   `json:"topics,omitempty"`
	Leads        []FactLead `json:"investigation_leads,omitempty"`
}

type FactLead struct {
	FactID     string `json:"fact_id"`
	Confidence int    `json:"confidence"`
}

type Belief struct {
	FactID           string           `json:"fact_id"`
	Claim            string           `json:"claim"`
	Confidence       int              `json:"confidence"`
	Source           string           `json:"source"`
	SourceEventID    string           `json:"source_event_id,omitempty"`
	LearnedOn        int              `json:"learned_on"`
	Secrecy          int              `json:"secrecy"`
	EvidenceStrength int              `json:"evidence_strength,omitempty"`
	Contested        bool             `json:"contested,omitempty"`
	Evidence         []BeliefEvidence `json:"evidence,omitempty"`
}

type BeliefEvidence struct {
	Claim         string `json:"claim"`
	Strength      int    `json:"strength"`
	Confidence    int    `json:"confidence"`
	Source        string `json:"source"`
	SourceEventID string `json:"source_event_id,omitempty"`
	LearnedOn     int    `json:"learned_on"`
}

type Personality struct {
	Caution       int `json:"caution"`
	Greed         int `json:"greed"`
	Loyalty       int `json:"loyalty"`
	Ambition      int `json:"ambition"`
	Credit        int `json:"credit"`
	RiskTolerance int `json:"risk_tolerance"`
}

type NPCConfig struct {
	ID              string           `json:"id"`
	Name            string           `json:"name"`
	Faction         string           `json:"faction"`
	PublicProfile   string           `json:"public_profile,omitempty"`
	PublicRole      string           `json:"public_role,omitempty"`
	PublicGoal      string           `json:"public_goal,omitempty"`
	TrackPublicPlan bool             `json:"track_public_plan,omitempty"`
	PublicInterests []PublicInterest `json:"public_interests,omitempty"`
	PublicRisk      string           `json:"public_risk,omitempty"`
	Goal            string           `json:"goal"`
	Goals           []Goal           `json:"goals,omitempty"`
	Interests       []string         `json:"interests,omitempty"`
	Location        string           `json:"location"`
	Injury          int              `json:"injury"`
	Resources       map[string]int   `json:"resources"`
	Items           []string         `json:"items"`
	Beliefs         []Belief         `json:"beliefs"`
	Personality     Personality      `json:"personality"`
	Strategies      []Strategy       `json:"strategies"`
}

type PublicInterest struct {
	Topic string `json:"topic"`
	Label string `json:"label"`
}

type Goal struct {
	Type     string   `json:"type"`
	TargetID string   `json:"target_id,omitempty"`
	Priority int      `json:"priority"`
	Topics   []string `json:"topics,omitempty"`
}

type Strategy struct {
	ID                   string         `json:"id"`
	ActionID             string         `json:"action_id"`
	Description          string         `json:"description"`
	PublicDescription    string         `json:"public_description,omitempty"`
	TargetID             string         `json:"target_id"`
	FromDay              int            `json:"from_day"`
	UntilDay             int            `json:"until_day"`
	Duration             int            `json:"duration"`
	Once                 bool           `json:"once"`
	Conditions           []Condition    `json:"conditions"`
	CompletionConditions []Condition    `json:"completion_conditions,omitempty"`
	Score                ScoreInput     `json:"score"`
	Effects              []Effect       `json:"effects"`
	Costs                map[string]int `json:"costs,omitempty"`
	Generated            bool           `json:"-"`
	GoalTypes            []string       `json:"goal_types,omitempty"`
	PlanID               string         `json:"-"`
	PlanStepID           string         `json:"-"`
}

type ConditionType string

const (
	ConditionBelief          ConditionType = "belief"
	ConditionBeliefMax       ConditionType = "belief_max"
	ConditionHasItem         ConditionType = "has_item"
	ConditionMissingItem     ConditionType = "missing_item"
	ConditionLocation        ConditionType = "location"
	ConditionFlag            ConditionType = "flag"
	ConditionMissingFlag     ConditionType = "missing_flag"
	ConditionResourceAtLeast ConditionType = "resource_at_least"
	ConditionResourceAtMost  ConditionType = "resource_at_most"
	ConditionInjuryAtLeast   ConditionType = "injury_at_least"
	ConditionInjuryAtMost    ConditionType = "injury_at_most"
	ConditionOpportunity     ConditionType = "opportunity"
)

func (conditionType ConditionType) Valid() bool {
	switch conditionType {
	case ConditionBelief, ConditionBeliefMax, ConditionHasItem, ConditionMissingItem,
		ConditionLocation, ConditionFlag, ConditionMissingFlag, ConditionResourceAtLeast,
		ConditionResourceAtMost, ConditionInjuryAtLeast, ConditionInjuryAtMost, ConditionOpportunity:
		return true
	default:
		return false
	}
}

type Condition struct {
	Type          ConditionType `json:"type"`
	Scope         string        `json:"scope,omitempty"`
	Key           string        `json:"key"`
	Value         string        `json:"value"`
	MinConfidence int           `json:"min_confidence"`
	MaxConfidence int           `json:"max_confidence"`
}

type ScoreInput struct {
	Base         int `json:"base"`
	Goal         int `json:"goal"`
	Urgency      int `json:"urgency"`
	Probability  int `json:"probability"`
	Information  int `json:"information"`
	Relationship int `json:"relationship"`
	Cost         int `json:"cost"`
	Danger       int `json:"danger"`
}

type EffectType string

const (
	EffectMove             EffectType = "move"
	EffectAddItem          EffectType = "add_item"
	EffectRemoveItem       EffectType = "remove_item"
	EffectMarketBuy        EffectType = "market_buy"
	EffectAdjustResource   EffectType = "adjust_resource"
	EffectAdjustInjury     EffectType = "adjust_injury"
	EffectSetBelief        EffectType = "set_belief"
	EffectSetFlag          EffectType = "set_flag"
	EffectTransferUnique   EffectType = "transfer_unique"
	EffectSetOutcome       EffectType = "set_outcome"
	EffectAdjustRelation   EffectType = "adjust_relation"
	EffectOpenOpportunity  EffectType = "open_opportunity"
	EffectCloseOpportunity EffectType = "close_opportunity"
	EffectSetStoryState    EffectType = "set_story_state"
)

func (effectType EffectType) Valid() bool {
	switch effectType {
	case EffectMove, EffectAddItem, EffectRemoveItem, EffectMarketBuy, EffectAdjustResource,
		EffectAdjustInjury, EffectSetBelief, EffectSetFlag, EffectTransferUnique, EffectSetOutcome,
		EffectAdjustRelation, EffectOpenOpportunity, EffectCloseOpportunity, EffectSetStoryState:
		return true
	default:
		return false
	}
}

type Effect struct {
	Type             EffectType `json:"type"`
	Scope            string     `json:"scope,omitempty"`
	FromID           string     `json:"from_id"`
	TargetID         string     `json:"target_id"`
	Key              string     `json:"key"`
	Value            string     `json:"value"`
	Amount           int        `json:"amount"`
	FactID           string     `json:"fact_id"`
	Claim            string     `json:"claim"`
	Confidence       int        `json:"confidence"`
	EvidenceStrength int        `json:"evidence_strength,omitempty"`
	Propagation      string     `json:"propagation,omitempty"`
	DelayDays        int        `json:"delay_days,omitempty"`
	Distortion       int        `json:"distortion,omitempty"`
	Secrecy          int        `json:"secrecy,omitempty"`
	Source           string     `json:"source,omitempty"`
	BypassRouteFlag  bool       `json:"bypass_route_flag,omitempty"`
}

type ItemDefinition struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	Unique bool   `json:"unique"`
	Owner  string `json:"owner"`
}

type Location struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	Safe        bool    `json:"safe"`
	MapX        float64 `json:"map_x,omitempty"`
	MapY        float64 `json:"map_y,omitempty"`
	SceneKey    string  `json:"scene_key,omitempty"`
	Description string  `json:"description,omitempty"`
	Atmosphere  string  `json:"atmosphere,omitempty"`
	Routes      []Route `json:"routes"`
}

type Route struct {
	To           string `json:"to"`
	Duration     int    `json:"duration"`
	RequiredItem string `json:"required_item,omitempty"`
	RequiredFlag string `json:"required_flag,omitempty"`
	Danger       int    `json:"danger"`
}

type Bundle struct {
	Content       ContentMetadata
	Scenario      Scenario
	StoryArcs     map[string]StoryArc
	Flags         map[string]FlagDefinition
	Actions       map[string]ActionDefinition
	Facts         map[string]Fact
	NPCs          []NPCConfig
	Items         map[string]ItemDefinition
	Locations     map[string]Location
	DefaultPlayer PlayerConfig
	// InitialRelations allows deterministic simulations and parameter sweeps to
	// start from explicit directional relationship state.
	InitialRelations []Relation
}

type ContentMetadata struct {
	SchemaVersion       int    `json:"schema_version"`
	Version             string `json:"content_version"`
	Hash                string `json:"content_hash"`
	EngineCompatibility string `json:"engine_compatibility,omitempty"`
}

type RunPlan struct {
	ID       string          `json:"id"`
	Title    string          `json:"title"`
	Player   PlayerConfig    `json:"player"`
	Commands []PlayerCommand `json:"commands"`
}

type PlayerConfig struct {
	ID        string         `json:"id"`
	Name      string         `json:"name"`
	Location  string         `json:"location"`
	Injury    int            `json:"injury"`
	Resources map[string]int `json:"resources"`
	Items     []string       `json:"items"`
	Beliefs   []Belief       `json:"beliefs"`
}

type PlayerCommand struct {
	ID                   string         `json:"id"`
	Day                  int            `json:"day"`
	ActionID             string         `json:"action_id"`
	Duration             int            `json:"duration"`
	TargetID             string         `json:"target_id"`
	Description          string         `json:"description"`
	Conditions           []Condition    `json:"conditions"`
	CompletionConditions []Condition    `json:"completion_conditions,omitempty"`
	Effects              []Effect       `json:"effects"`
	Costs                map[string]int `json:"costs,omitempty"`
	OnFailure            string         `json:"on_failure,omitempty"`
	Fallback             *PlayerCommand `json:"fallback,omitempty"`
}

type PlayerState struct {
	ID        string
	Name      string
	Location  string
	Injury    int
	Resources map[string]int
	Items     map[string]int
	Beliefs   map[string]Belief
	Pending   *PendingAction
}

type NPCState struct {
	ID           string
	Name         string
	Faction      string
	Goal         string
	Goals        []Goal
	Interests    []string
	Location     string
	Injury       int
	Resources    map[string]int
	Items        map[string]int
	Beliefs      map[string]Belief
	Personality  Personality
	Strategies   []Strategy
	Completed    map[string]bool
	Pending      *PendingAction
	Plans        map[string]*PlanChain
	ActivePlanID string
}

type PlanChain struct {
	ID            string
	GoalType      string
	TargetID      string
	CreatedDay    int
	CurrentStepID string
	Status        string
	Steps         []PlanStep
}

type PlanStep struct {
	ID          string
	Description string
	Status      string
}

type WorldState struct {
	RunID              string
	RunTitle           string
	Day                int
	Phase              string
	NPCs               map[string]*NPCState
	Player             *PlayerState
	Facts              map[string]Fact
	Items              map[string]string
	WorldFlags         map[string]bool
	ActorFlags         map[string]map[string]bool
	WorldFlagSources   map[string]string
	ActorFlagSources   map[string]map[string]string
	ItemSources        map[string]string
	Relations          map[string]Relation
	Opportunities      map[string]string
	OpportunitySources map[string]string
	StoryStates        map[string]string
	PendingInformation []InformationDelivery
	Markets            map[string]*MarketState
	Debts              map[string]*Debt
	Alliances          map[string]*Alliance
	Agreements         map[string]*Agreement
	Events             []WorldEvent
	Decisions          []DecisionRecord
	Director           WorldDirectorState
	DirectorDecisions  []DirectorDecision
	Outcome            string
}

type WorldDirectorState struct {
	LastPhase        string
	LastDirectiveDay int
	Uses             map[string]int
	LastUsedDay      map[string]int
}

type WorldSignal struct {
	Type        string
	SubjectID   string
	Value       int
	Description string
}

type DirectorDecision struct {
	Day         int
	DirectiveID string
	Trigger     string
	Description string
	Score       int
	Source      string
	Signals     []WorldSignal
	EventID     string
}

type Debt struct {
	ID             string
	CreditorID     string
	DebtorID       string
	Resource       string
	Principal      int
	Outstanding    int
	DueDay         int
	Status         string
	CreatedEventID string
	SettledEventID string
}

type LoanRequest struct {
	ID         string
	CreditorID string
	DebtorID   string
	Resource   string
	Amount     int
	DueDay     int
}

type Alliance struct {
	ID             string
	Members        []string
	GoalType       string
	TargetID       string
	BenefitShares  map[string]int
	Status         string
	BetrayerID     string
	CreatedEventID string
	BrokenEventID  string
}

type AllianceRequest struct {
	ID            string
	Members       []string
	GoalType      string
	TargetID      string
	MinTrust      int
	BenefitShares map[string]int
}

type Agreement struct {
	ID             string
	Mode           string
	Parties        []string
	ItemID         string
	CustodianID    string
	Shares         map[string]int
	Price          int
	Status         string
	SettledEventID string
}

type AgreementRequest struct {
	ID          string
	Mode        string
	OwnerID     string
	CustodianID string
	ItemID      string
	Price       int
	Shares      map[string]int
}

type InformationDelivery struct {
	DeliverDay    int
	SourceActorID string
	TargetID      string
	SourceEventID string
	Belief        Belief
}

type InformationTrade struct {
	ID             string
	Mode           string
	FromID         string
	ToID           string
	FactID         string
	ExchangeFactID string
	Price          int
	Distortion     int
}

type Relation struct {
	From       string
	To         string
	Trust      int
	Suspicion  int
	Fear       int
	Dependence int
	Hatred     int
	Debt       int
}

type ScoreBreakdown struct {
	Base         int
	Goal         int
	Urgency      int
	Probability  int
	Information  int
	Relationship int
	Cost         int
	Danger       int
	Personality  int
	Total        int
}

type RankedChoice struct {
	StrategyID  string
	ActionID    string
	Description string
	Score       ScoreBreakdown
	Generated   bool
}

type DecisionRecord struct {
	Day                           int
	ActorID                       string
	ActorName                     string
	Choices                       []RankedChoice
	RelationshipRelevant          bool
	RelationshipChangedTop        bool
	WithoutRelationshipStrategyID string
	Counterfactuals               []CounterfactualRecord
}

type CounterfactualRecord struct {
	Kind                  string
	RemovedKey            string
	TriggerEventID        string
	OriginalStrategyID    string
	AlternativeStrategyID string
	Changed               bool
}

type ActionIntent struct {
	ID              string
	Day             int
	ActorID         string
	TargetID        string
	Action          ActionDefinition
	Strategy        Strategy
	Score           ScoreBreakdown
	Player          bool
	TriggerEventIDs []string
}

type PendingAction struct {
	Intent       ActionIntent
	StartedDay   int
	CompleteDay  int
	PaidCosts    map[string]int
	StartEventID string
}

type WorldEvent struct {
	ID              string
	Day             int
	Type            string
	ActionID        string
	StrategyID      string
	IntentID        string
	ParentEventID   string
	TriggerEventIDs []string
	PlanID          string
	PlanStepID      string
	ActorID         string
	TargetID        string
	Description     string
	CauseID         string
	Effects         []Effect
	Conditions      []Condition
}

func (w *WorldState) NPC(id string) (*NPCState, error) {
	npc, ok := w.NPCs[id]
	if !ok {
		return nil, fmt.Errorf("unknown NPC %q", id)
	}
	return npc, nil
}

func RelationKey(from, to string) string {
	return from + "->" + to
}

func (w *WorldState) RelationBetween(from, to string) Relation {
	return w.Relations[RelationKey(from, to)]
}

func (w *WorldState) WorldFlag(key string) bool {
	return w.WorldFlags[key]
}

func (w *WorldState) ActorFlag(actorID, key string) bool {
	return w.ActorFlags[actorID][key]
}

func (w *WorldState) SetWorldFlag(key string, value bool) {
	w.SetWorldFlagWithSource(key, value, "")
}

func (w *WorldState) SetWorldFlagWithSource(key string, value bool, sourceEventID string) {
	if w.WorldFlags == nil {
		w.WorldFlags = make(map[string]bool)
	}
	w.WorldFlags[key] = value
	if w.WorldFlagSources == nil {
		w.WorldFlagSources = make(map[string]string)
	}
	w.WorldFlagSources[key] = sourceEventID
}

func (w *WorldState) SetActorFlag(actorID, key string, value bool) {
	w.SetActorFlagWithSource(actorID, key, value, "")
}

func (w *WorldState) SetActorFlagWithSource(actorID, key string, value bool, sourceEventID string) {
	if w.ActorFlags == nil {
		w.ActorFlags = make(map[string]map[string]bool)
	}
	if w.ActorFlags[actorID] == nil {
		w.ActorFlags[actorID] = make(map[string]bool)
	}
	w.ActorFlags[actorID][key] = value
	if w.ActorFlagSources == nil {
		w.ActorFlagSources = make(map[string]map[string]string)
	}
	if w.ActorFlagSources[actorID] == nil {
		w.ActorFlagSources[actorID] = make(map[string]string)
	}
	w.ActorFlagSources[actorID][key] = sourceEventID
}

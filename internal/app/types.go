package app

type PlayerView struct {
	ScenarioID       string             `json:"scenario_id"`
	Title            string             `json:"title"`
	Day              int                `json:"day"`
	Duration         int                `json:"duration"`
	Phase            string             `json:"phase"`
	Ended            bool               `json:"ended"`
	Resolved         bool               `json:"resolved"`
	Outcome          string             `json:"outcome,omitempty"`
	Player           VisiblePlayer      `json:"player"`
	Location         VisibleLocation    `json:"location"`
	WorldMap         VisibleWorldMap    `json:"world_map"`
	KnownActors      []VisibleActor     `json:"known_actors"`
	KnownFacts       []VisibleBelief    `json:"known_facts"`
	RecentEvents     []VisibleEvent     `json:"recent_events"`
	CausalThreads    []VisibleInfluence `json:"causal_threads,omitempty"`
	AvailableActions []AvailableAction  `json:"available_actions"`
	Guidance         []string           `json:"guidance,omitempty"`
	LastTurn         *TurnFeedback      `json:"last_turn,omitempty"`
	Ending           *EndingSummary     `json:"ending,omitempty"`
	Metrics          PlayMetrics        `json:"metrics"`
	Travel           *TravelGuidance    `json:"travel,omitempty"`
	Preparation      PreparationSummary `json:"preparation"`
	RouteProgress    *RouteProgress     `json:"route_progress,omitempty"`
}

type TurnFeedback struct {
	Day          int                `json:"day"`
	DaysAdvanced int                `json:"days_advanced"`
	QuietDays    int                `json:"quiet_days,omitempty"`
	ActionID     string             `json:"action_id"`
	Action       string             `json:"action"`
	Status       string             `json:"status"`
	Messages     []string           `json:"messages"`
	Influence    []VisibleInfluence `json:"influence,omitempty"`
	Presentation *PresentationCue   `json:"presentation,omitempty"`
	StopReason   string             `json:"stop_reason,omitempty"`
}

type PreparationSummary struct {
	ScoreSources []PreparationFactor `json:"score_sources"`
	Conditions   []PreparationFactor `json:"conditions"`
	TotalScore   int                 `json:"total_score"`
	TargetScore  int                 `json:"target_score"`
	Rating       string              `json:"rating"`
	RatingDetail string              `json:"rating_detail"`
	Eligible     bool                `json:"eligible"`
}

type RouteProgress struct {
	ID             string `json:"id"`
	Label          string `json:"label"`
	Status         string `json:"status"`
	NextStep       string `json:"next_step"`
	Window         string `json:"window,omitempty"`
	DeadlineDay    int    `json:"deadline_day,omitempty"`
	Location       string `json:"location,omitempty"`
	PersonalReturn string `json:"personal_return,omitempty"`
	Urgent         bool   `json:"urgent"`
	Complete       bool   `json:"complete"`
}

type PreparationFactor struct {
	Key    string `json:"key"`
	Label  string `json:"label"`
	Value  int    `json:"value,omitempty"`
	Status string `json:"status"`
	Ready  bool   `json:"ready"`
}

type PresentationCue struct {
	Kind      string `json:"kind"`
	Intensity int    `json:"intensity"`
	SubjectID string `json:"subject_id,omitempty"`
}

type EndingSummary struct {
	Outcome            string             `json:"outcome"`
	PlayerConsequences []string           `json:"player_consequences,omitempty"`
	Review             []string           `json:"review,omitempty"`
	Highlights         []string           `json:"highlights"`
	Influence          []VisibleInfluence `json:"influence,omitempty"`
}

type VisibleInfluence struct {
	ActorName    string                  `json:"actor_name"`
	FactID       string                  `json:"fact_id"`
	FactClaim    string                  `json:"fact_claim"`
	DeliveredDay int                     `json:"delivered_day"`
	Stage        string                  `json:"stage"`
	StageLabel   string                  `json:"stage_label"`
	Summary      string                  `json:"summary"`
	Changes      []VisibleDecisionChange `json:"changes,omitempty"`
}

type VisibleDecisionChange struct {
	Day                int    `json:"day"`
	WithoutInformation string `json:"without_information"`
	WithInformation    string `json:"with_information"`
}

type PlayMetrics struct {
	DecisionInputs          int `json:"decision_inputs"`
	Turns                   int `json:"turns"`
	ActiveActions           int `json:"active_actions"`
	WaitActions             int `json:"wait_actions"`
	MaxActionCatalog        int `json:"max_action_catalog"`
	LongestQuietWait        int `json:"longest_quiet_wait"`
	MaxRepeatedActiveAction int `json:"max_repeated_active_action"`
	VisibleDecisionChanges  int `json:"visible_decision_changes"`
	CoreResultDay           int `json:"core_result_day,omitempty"`
	PostResultInputs        int `json:"post_result_inputs"`
	AutoAdvancedDays        int `json:"auto_advanced_days"`
}

type TravelGuidance struct {
	Destination string        `json:"destination"`
	TravelDays  int           `json:"travel_days"`
	Ready       bool          `json:"ready"`
	Blockers    []string      `json:"blockers,omitempty"`
	Timing      string        `json:"timing,omitempty"`
	Route       []string      `json:"route,omitempty"`
	Checks      []TravelCheck `json:"checks,omitempty"`
}

type TravelCheck struct {
	Label string `json:"label"`
	Ready bool   `json:"ready"`
}

type VisiblePlayer struct {
	ID         string         `json:"id"`
	Name       string         `json:"name"`
	Injury     int            `json:"injury"`
	Resources  map[string]int `json:"resources"`
	Items      []VisibleItem  `json:"items"`
	Busy       bool           `json:"busy"`
	BusyUntil  int            `json:"busy_until,omitempty"`
	BusyAction string         `json:"busy_action,omitempty"`
}

type VisibleLocation struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Safe        bool   `json:"safe"`
	SceneKey    string `json:"scene_key,omitempty"`
	Description string `json:"description,omitempty"`
	Atmosphere  string `json:"atmosphere,omitempty"`
}

type VisibleWorldMap struct {
	Locations []VisibleMapLocation `json:"locations"`
	Routes    []VisibleMapRoute    `json:"routes"`
}

type VisibleMapLocation struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	Safe        bool    `json:"safe"`
	X           float64 `json:"x"`
	Y           float64 `json:"y"`
	SceneKey    string  `json:"scene_key,omitempty"`
	Description string  `json:"description,omitempty"`
	Atmosphere  string  `json:"atmosphere,omitempty"`
	Current     bool    `json:"current"`
	Contest     bool    `json:"contest"`
	ActorCount  int     `json:"actor_count,omitempty"`
}

type VisibleMapRoute struct {
	FromID   string   `json:"from_id"`
	ToID     string   `json:"to_id"`
	Duration int      `json:"duration"`
	Danger   int      `json:"danger"`
	Status   string   `json:"status"`
	ActionID string   `json:"action_id,omitempty"`
	Blockers []string `json:"blockers,omitempty"`
}

type VisibleActor struct {
	ID            string   `json:"id"`
	Name          string   `json:"name"`
	Faction       string   `json:"faction"`
	PublicProfile string   `json:"public_profile"`
	PublicRole    string   `json:"public_role,omitempty"`
	PublicFocus   []string `json:"public_focus,omitempty"`
	PublicRisk    string   `json:"public_risk,omitempty"`
}

type VisibleBelief struct {
	FactID     string `json:"fact_id"`
	Claim      string `json:"claim"`
	Confidence int    `json:"confidence"`
	Source     string `json:"source"`
	LearnedOn  int    `json:"learned_on"`
	Contested  bool   `json:"contested"`
}

type VisibleEvent struct {
	Day         int    `json:"day"`
	Type        string `json:"type"`
	ActorName   string `json:"actor_name"`
	Description string `json:"description"`
}

type VisibleItem struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	Amount int    `json:"amount"`
}

type AvailableAction struct {
	ID               string         `json:"id"`
	Kind             string         `json:"kind"`
	Category         string         `json:"category"`
	Name             string         `json:"name"`
	Description      string         `json:"description"`
	Duration         int            `json:"duration"`
	CompletionDay    int            `json:"completion_day,omitempty"`
	Timing           string         `json:"timing,omitempty"`
	ExpectedOutcomes []string       `json:"expected_outcomes,omitempty"`
	Resolves         []string       `json:"resolves,omitempty"`
	Costs            map[string]int `json:"costs,omitempty"`
	TargetID         string         `json:"target_id,omitempty"`
	TargetName       string         `json:"target_name,omitempty"`
	FactID           string         `json:"fact_id,omitempty"`
	FactClaim        string         `json:"fact_claim,omitempty"`
	TermID           string         `json:"term_id,omitempty"`
	TermLabel        string         `json:"term_label,omitempty"`
	PersonalOutcome  string         `json:"personal_outcome,omitempty"`
	TargetRole       string         `json:"target_role,omitempty"`
	Relevance        string         `json:"relevance,omitempty"`
	Risk             string         `json:"risk,omitempty"`
	Warnings         []string       `json:"warnings,omitempty"`
	KnownConditions  []string       `json:"known_conditions,omitempty"`
	Unknowns         []string       `json:"unknowns,omitempty"`
	Irreversible     bool           `json:"irreversible,omitempty"`
}

package app

type PlayerView struct {
	ScenarioID       string            `json:"scenario_id"`
	Title            string            `json:"title"`
	Day              int               `json:"day"`
	Duration         int               `json:"duration"`
	Phase            string            `json:"phase"`
	Ended            bool              `json:"ended"`
	Resolved         bool              `json:"resolved"`
	Outcome          string            `json:"outcome,omitempty"`
	Player           VisiblePlayer     `json:"player"`
	Location         VisibleLocation   `json:"location"`
	KnownActors      []VisibleActor    `json:"known_actors"`
	KnownFacts       []VisibleBelief   `json:"known_facts"`
	RecentEvents     []VisibleEvent    `json:"recent_events"`
	AvailableActions []AvailableAction `json:"available_actions"`
	Guidance         []string          `json:"guidance,omitempty"`
	LastTurn         *TurnFeedback     `json:"last_turn,omitempty"`
	Ending           *EndingSummary    `json:"ending,omitempty"`
	Metrics          PlayMetrics       `json:"metrics"`
}

type TurnFeedback struct {
	Day       int                `json:"day"`
	ActionID  string             `json:"action_id"`
	Action    string             `json:"action"`
	Status    string             `json:"status"`
	Messages  []string           `json:"messages"`
	Influence []VisibleInfluence `json:"influence,omitempty"`
}

type EndingSummary struct {
	Outcome    string             `json:"outcome"`
	Highlights []string           `json:"highlights"`
	Influence  []VisibleInfluence `json:"influence,omitempty"`
}

type VisibleInfluence struct {
	ActorName    string                  `json:"actor_name"`
	FactID       string                  `json:"fact_id"`
	FactClaim    string                  `json:"fact_claim"`
	DeliveredDay int                     `json:"delivered_day"`
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
	ID   string `json:"id"`
	Name string `json:"name"`
	Safe bool   `json:"safe"`
}

type VisibleActor struct {
	ID      string `json:"id"`
	Name    string `json:"name"`
	Faction string `json:"faction"`
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
	ID          string         `json:"id"`
	Category    string         `json:"category"`
	Name        string         `json:"name"`
	Description string         `json:"description"`
	Duration    int            `json:"duration"`
	Costs       map[string]int `json:"costs,omitempty"`
}

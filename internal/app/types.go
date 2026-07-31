package app

type PlayerView struct {
	ScenarioID       string            `json:"scenario_id"`
	Title            string            `json:"title"`
	Day              int               `json:"day"`
	Duration         int               `json:"duration"`
	Phase            string            `json:"phase"`
	Ended            bool              `json:"ended"`
	Outcome          string            `json:"outcome,omitempty"`
	Player           VisiblePlayer     `json:"player"`
	Location         VisibleLocation   `json:"location"`
	KnownActors      []VisibleActor    `json:"known_actors"`
	KnownFacts       []VisibleBelief   `json:"known_facts"`
	RecentEvents     []VisibleEvent    `json:"recent_events"`
	AvailableActions []AvailableAction `json:"available_actions"`
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

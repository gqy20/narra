package ai

import "sync"

type dialogueCache struct {
	mu      sync.Mutex
	limit   int
	order   []string
	entries map[string]Dialogue
}

func newDialogueCache(limit int) *dialogueCache {
	return &dialogueCache{limit: limit, entries: make(map[string]Dialogue)}
}

func (c *dialogueCache) get(key string) (Dialogue, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	value, ok := c.entries[key]
	return value, ok
}

func (c *dialogueCache) put(key string, value Dialogue) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if _, exists := c.entries[key]; exists {
		c.entries[key] = value
		return
	}
	if len(c.order) >= c.limit {
		oldest := c.order[0]
		c.order = c.order[1:]
		delete(c.entries, oldest)
	}
	c.order = append(c.order, key)
	c.entries[key] = value
}

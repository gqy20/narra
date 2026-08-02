package report

import (
	"bytes"
	"path/filepath"
	"strings"
	"testing"

	"fantu/internal/engine"
	"fantu/internal/scenario"
)

func TestMarkdownIncludesWorldDirectorAudit(t *testing.T) {
	bundle, err := scenario.Load(filepath.Join("..", "..", "data", "blackwind"))
	if err != nil {
		t.Fatal(err)
	}
	state, err := engine.New(bundle).RunUntil(3)
	if err != nil {
		t.Fatal(err)
	}
	var output bytes.Buffer
	if err := Markdown(&output, state, bundle); err != nil {
		t.Fatal(err)
	}
	text := output.String()
	for _, want := range []string{"世界导演决策：1", "## 世界导演审计", "quiet-broker-arrival", "quiet_days:world=3"} {
		if !strings.Contains(text, want) {
			t.Errorf("report missing %q:\n%s", want, text)
		}
	}
}

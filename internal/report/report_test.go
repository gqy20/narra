package report

import (
	"bytes"
	"strings"
	"testing"

	"narra/internal/engine"
	"narra/internal/testsupport"
)

func TestMarkdownIncludesWorldDirectorAudit(t *testing.T) {
	bundle := testsupport.LoadOfficialWorld(t, "blackwind")
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

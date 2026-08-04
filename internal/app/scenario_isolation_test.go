package app

import (
	"encoding/json"
	"strings"
	"testing"

	"narra/internal/scenario"
)

func TestTianqiPlayerViewDoesNotLeakBlackwindLanguage(t *testing.T) {
	bundle, err := scenario.Load("../../data/tianqi")
	if err != nil {
		t.Fatal(err)
	}
	session, err := NewSession(bundle, DefaultPlayer(bundle, "切换测试抄手"))
	if err != nil {
		t.Fatal(err)
	}
	encoded, err := json.Marshal(session.View())
	if err != nil {
		t.Fatal(err)
	}
	text := string(encoded)
	for _, forbidden := range []string{"黑风谷", "青髓芝", "解瘴丹", "灵石", "战力", "青岚门"} {
		if strings.Contains(text, forbidden) {
			t.Fatalf("tianqi player view leaked %q: %s", forbidden, text)
		}
	}
}

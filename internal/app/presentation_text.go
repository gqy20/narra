package app

import (
	"fmt"
	"strconv"
	"strings"
)

func (s *Session) uiText(key string, values ...string) string {
	text := s.bundle.Presentation.UI[key]
	if text == "" {
		panic(fmt.Sprintf("missing required presentation ui text %q", key))
	}
	for index := 0; index+1 < len(values); index += 2 {
		text = strings.ReplaceAll(text, "{"+values[index]+"}", values[index+1])
	}
	return text
}

func intText(value int) string { return strconv.Itoa(value) }

func (s *Session) confidenceText(value int) string {
	switch {
	case value >= 3:
		return s.uiText("confidence_confirmed")
	case value == 2:
		return s.uiText("confidence_plausible")
	default:
		return s.uiText("confidence_rumored")
	}
}

package app

import (
	"fmt"

	"fantu/internal/domain"
)

func (s *Session) routeProgresses(state *domain.WorldState) []RouteProgress {
	return s.storyRouteProgresses(state)
}

func routeProgressWarnings(progresses []RouteProgress, day int) []string {
	warnings := make([]string, 0, len(progresses))
	for index := range progresses {
		progress := &progresses[index]
		if progress.Complete || !progress.Urgent {
			continue
		}
		deadline := ""
		if progress.DeadlineDay > 0 {
			deadline = fmt.Sprintf("；最迟第 %d 日处理", progress.DeadlineDay)
		}
		warnings = append(warnings, fmt.Sprintf("路线提醒 · %s：%s%s。", progress.Label, progress.NextStep, deadline))
	}
	return warnings
}

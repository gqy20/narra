package app

import (
	"fmt"

	"fantu/internal/domain"
)

func (s *Session) routeProgress(state *domain.WorldState) *RouteProgress {
	return s.storyRouteProgress(state)
}

func routeProgressWarning(progress *RouteProgress, day int) string {
	if progress == nil || progress.Complete || !progress.Urgent {
		return ""
	}
	deadline := ""
	if progress.DeadlineDay > 0 {
		deadline = fmt.Sprintf("；最迟第 %d 日处理", progress.DeadlineDay)
	}
	return fmt.Sprintf("路线提醒 · %s：%s%s。", progress.Label, progress.NextStep, deadline)
}

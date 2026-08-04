package app

import (
	"strings"

	"narra/internal/domain"
)

const quietWaitMessage = "一天过去，局势继续发展。"

func (s *Session) recordCatalogSize(size int) {
	if size > s.metrics.MaxActionCatalog {
		s.metrics.MaxActionCatalog = size
	}
}

func (s *Session) recordMetrics(actionID string, before, after *domain.WorldState, feedback *TurnFeedback) {
	s.metrics.DecisionInputs++
	s.metrics.Turns = after.Day
	if before.Outcome != "" {
		s.metrics.PostResultInputs++
	}
	if strings.HasPrefix(actionID, "wait") {
		s.metrics.WaitActions++
		if feedback.QuietDays > 0 {
			s.quietWaitStreak += feedback.QuietDays
		} else if len(feedback.Messages) == 1 && feedback.Messages[0] == quietWaitMessage && len(feedback.Influence) == 0 {
			s.quietWaitStreak += maxInt(1, feedback.DaysAdvanced)
		}
		if s.quietWaitStreak > 0 {
			if s.quietWaitStreak > s.metrics.LongestQuietWait {
				s.metrics.LongestQuietWait = s.quietWaitStreak
			}
			if feedback.QuietDays < feedback.DaysAdvanced {
				s.quietWaitStreak = 0
			}
		} else {
			s.quietWaitStreak = 0
		}
		if actionID != "wait" {
			s.metrics.AutoAdvancedDays += feedback.DaysAdvanced
		}
	} else {
		s.metrics.ActiveActions++
		s.quietWaitStreak = 0
		category := actionID
		if index := strings.IndexByte(category, ':'); index >= 0 {
			category = category[:index]
		}
		if category == s.lastActiveAction {
			s.repeatedActiveAction++
		} else {
			s.lastActiveAction = category
			s.repeatedActiveAction = 1
		}
		if s.repeatedActiveAction > s.metrics.MaxRepeatedActiveAction {
			s.metrics.MaxRepeatedActiveAction = s.repeatedActiveAction
		}
	}
	for _, influence := range feedback.Influence {
		s.metrics.VisibleDecisionChanges += len(influence.Changes)
	}
	if before.Outcome == "" && after.Outcome != "" {
		s.metrics.CoreResultDay = after.Day
	}
}

func (s *Session) metricsView(state *domain.WorldState) PlayMetrics {
	metrics := s.metrics
	metrics.Turns = state.Day
	return metrics
}

package engine

import (
	"fmt"

	"narra/internal/domain"
)

func (e *Engine) deliverInformation(day int) error {
	remaining := make([]domain.InformationDelivery, 0, len(e.state.PendingInformation))
	for _, delivery := range e.state.PendingInformation {
		if delivery.DeliverDay > day {
			remaining = append(remaining, delivery)
			continue
		}
		if !e.actorExists(delivery.TargetID) {
			return fmt.Errorf("information delivery references unknown actor %s", delivery.TargetID)
		}
		event := e.newEvent("information_delivered", delivery.SourceActorID, delivery.TargetID, "延迟情报送达："+delivery.Belief.FactID, delivery.SourceEventID, nil)
		event.ParentEventID = delivery.SourceEventID
		belief := delivery.Belief
		belief.SourceEventID = event.ID
		belief.LearnedOn = day
		e.mergeActorBelief(delivery.TargetID, belief)
		e.state.Events = append(e.state.Events, event)
	}
	e.state.PendingInformation = remaining
	return nil
}

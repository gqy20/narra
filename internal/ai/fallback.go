package ai

import "fantu/internal/app"

func fallbackDialogue(snapshot app.DialogueSnapshot) Dialogue {
	utterance := "道友既然来了，不妨说说你的来意。"
	emotion := "neutral"
	act := "invite"
	for _, guidance := range snapshot.Actor.SpeechGuidance {
		if guidance == "措辞谨慎，先确认来意和消息来源" {
			utterance = "消息可以谈，但我得先知道它从何而来。"
			emotion = "alert"
			act = "question"
			break
		}
	}
	return Dialogue{
		ActorID: snapshot.Actor.ID, Revision: snapshot.Revision,
		Utterance: utterance, Emotion: emotion, DialogueAct: act,
		ReferencedFacts: []string{}, Source: "fallback",
	}
}

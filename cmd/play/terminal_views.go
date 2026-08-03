package main

import (
	"context"
	"fmt"
	"io"
	"strconv"
	"strings"
	"time"

	"fantu/internal/ai"
	"fantu/internal/app"
	"fantu/internal/domain"
)

func renderLocation(output io.Writer, view app.PlayerView) {
	fmt.Fprintf(output, "\n【%s】\n%s\n", view.Location.Name, view.Location.Description)
	if view.Location.Atmosphere != "" {
		fmt.Fprintln(output, view.Location.Atmosphere)
	}
	if len(view.RecentEvents) > 0 {
		fmt.Fprintln(output, "近日动向：")
		for _, event := range view.RecentEvents {
			fmt.Fprintf(output, "  - 第 %d 天：%s\n", event.Day, event.Description)
		}
	}
}

func renderPeople(output io.Writer, view app.PlayerView, debug bool) {
	fmt.Fprintf(output, "\n【%s · 同地人物】\n", view.Location.Name)
	if len(view.KnownActors) == 0 {
		fmt.Fprintln(output, "此地目前没有可交谈人物。")
		return
	}
	for index, actor := range view.KnownActors {
		id := ""
		if debug {
			id = " [" + actor.ID + "]"
		}
		role := actor.PublicRole
		if role == "" {
			role = actor.Faction
		}
		fmt.Fprintf(output, "  %d. %s%s · %s\n", index+1, actor.Name, id, role)
		if actor.PublicProfile != "" {
			fmt.Fprintf(output, "     %s\n", actor.PublicProfile)
		}
		if actor.Plan != nil && actor.Plan.Plan != "" {
			fmt.Fprintf(output, "     公开动向：%s\n", actor.Plan.Plan)
		}
	}
	fmt.Fprintln(output, "输入 talk <人物编号或姓名> 与人物交谈。")
}

type terminalDialogueSession struct {
	actor    app.VisibleActor
	revision string
}

type terminalDialogueAttempt struct {
	actor      app.VisibleActor
	snapshot   app.DialogueSnapshot
	playerText string
	opening    bool
}

type terminalDialogueResult struct {
	requestID uint64
	line      ai.Dialogue
	err       error
}

type terminalDialogueRequest struct {
	id      uint64
	attempt terminalDialogueAttempt
	result  chan terminalDialogueResult
	ticker  *time.Ticker
	started time.Time
	cancel  context.CancelFunc
}

func prepareDialogueStart(output io.Writer, game *terminalGame, dialogueService *ai.Service, view app.PlayerView, selector string, debug bool) (*terminalDialogueSession, *terminalDialogueAttempt) {
	if selector == "" {
		renderPeople(output, view, debug)
		return nil, nil
	}
	actor, err := resolveActor(selector, view.KnownActors, debug)
	if err != nil {
		fmt.Fprintf(output, "无法交谈：%v\n", err)
		return nil, nil
	}
	snapshot, err := game.session.DialogueSnapshotFor(actor.ID, "focus")
	if err != nil {
		fmt.Fprintf(output, "无法交谈：%v\n", err)
		return nil, nil
	}
	if dialogueService == nil {
		fmt.Fprintln(output, "人物对话未启用。请配置模型后重新启动，或继续使用规则行动。")
		return nil, nil
	}
	conversation := &terminalDialogueSession{actor: actor, revision: snapshot.Revision}
	attempt := &terminalDialogueAttempt{actor: actor, snapshot: snapshot, opening: true}
	return conversation, attempt
}

func prepareDialogueTurn(output io.Writer, game *terminalGame, conversation *terminalDialogueSession, playerText string) *terminalDialogueAttempt {
	snapshot, err := game.session.DialogueSnapshotFor(conversation.actor.ID, "focus")
	if err != nil || snapshot.Revision != conversation.revision {
		fmt.Fprintln(output, "局势已经变化，本次对话已结束；请重新使用 talk。")
		return nil
	}
	return &terminalDialogueAttempt{actor: conversation.actor, snapshot: snapshot, playerText: playerText}
}

func beginDialogueRequest(output io.Writer, session *app.Session, dialogueService *ai.Service, attempt terminalDialogueAttempt, requestID uint64) *terminalDialogueRequest {
	if attempt.opening {
		fmt.Fprintf(output, "\n%s正在生成开场回应；不会推进游戏时间。输入 cancel 可取消。\n", attempt.actor.Name)
	} else {
		fmt.Fprintf(output, "%s正在回应；不会推进游戏时间。输入 cancel 可取消。\n", attempt.actor.Name)
	}
	requestContext, cancel := context.WithCancel(context.Background())
	result := make(chan terminalDialogueResult, 1)
	go func() {
		history := session.DialogueHistory(attempt.snapshot.Actor.ID, attempt.snapshot.Revision, 8)
		line, generationErr := dialogueService.GenerateConversationTurn(requestContext, attempt.snapshot, history, attempt.playerText)
		result <- terminalDialogueResult{requestID: requestID, line: line, err: generationErr}
	}()
	return &terminalDialogueRequest{
		id: requestID, attempt: attempt, result: result,
		ticker: time.NewTicker(5 * time.Second), started: time.Now(), cancel: cancel,
	}
}

func stopDialogueRequest(request *terminalDialogueRequest) {
	if request == nil {
		return
	}
	request.cancel()
	request.ticker.Stop()
}

func recordDialogueTurn(game *terminalGame, snapshot app.DialogueSnapshot, playerText string, line ai.Dialogue) error {
	if err := game.session.RecordDialogue(app.DialogueExchange{
		ActorID: snapshot.Actor.ID, Revision: snapshot.Revision, PlayerText: playerText,
		NPCText: line.Utterance, Emotion: line.Emotion, DialogueAct: line.DialogueAct,
		ReferencedFacts: line.ReferencedFacts, SuggestedActions: line.SuggestedActions,
	}); err != nil {
		return err
	}
	if game.autosave && game.saves != nil {
		if err := game.saves.save(autosaveSlot, game.session); err != nil {
			return fmt.Errorf("autosave dialogue: %w", err)
		}
	}
	return nil
}

func renderDialogueReply(output io.Writer, actor app.VisibleActor, snapshot app.DialogueSnapshot, line ai.Dialogue, debug bool) {
	fmt.Fprintf(output, "%s：“%s”\n", actor.Name, line.Utterance)
	fmt.Fprintf(output, "态度：%s\n", snapshot.Relation.Attitude)
	if snapshot.PublicPlan != "" {
		fmt.Fprintf(output, "公开动向：%s\n", snapshot.PublicPlan)
	}
	if debug {
		fmt.Fprintf(output, "对话来源：%s；状态版本：%s\n", line.Source, line.Revision)
	}
}

func renderDialogueContext(output io.Writer, session *app.Session, conversation *terminalDialogueSession) {
	snapshot, err := session.DialogueSnapshotFor(conversation.actor.ID, "focus")
	if err != nil || snapshot.Revision != conversation.revision {
		fmt.Fprintln(output, "当前对话语境已经失效。")
		return
	}
	fmt.Fprintf(output, "对话语境：%s · 第 %d 天 · %s\n", conversation.actor.Name, snapshot.Day, snapshot.Relation.Attitude)
	if snapshot.PublicPlan != "" {
		fmt.Fprintln(output, "公开动向："+snapshot.PublicPlan)
	}
	history := session.DialogueHistory(conversation.actor.ID, conversation.revision, 8)
	fmt.Fprintf(output, "最近 %d 轮对话：\n", len(history))
	for _, exchange := range history {
		if exchange.PlayerText != "" {
			fmt.Fprintf(output, "  你：%s\n", exchange.PlayerText)
		}
		fmt.Fprintf(output, "  %s：%s\n", conversation.actor.Name, exchange.NPCText)
	}
}

func renderDirectorAudit(output io.Writer, decisions []domain.DirectorDecision, debug, showAll bool) {
	if len(decisions) == 0 {
		fmt.Fprintln(output, "世界导演尚未作出任何决策。")
		return
	}
	start := len(decisions) - 1
	if showAll {
		start = 0
	}
	fmt.Fprintln(output, "世界导演审计：")
	for _, decision := range decisions[start:] {
		fmt.Fprintf(output, "  第 %d 天 · %s\n", decision.Day, decision.Description)
		if debug {
			fmt.Fprintf(output, "    指令：%s；来源：%s；事件：%s\n", decision.DirectiveID, decision.Source, decision.EventID)
		} else {
			fmt.Fprintf(output, "    来源：%s\n", directorSourceLabel(decision.Source))
		}
		if decision.Reason != "" {
			fmt.Fprintf(output, "    选择理由：%s\n", decision.Reason)
		}
		if len(decision.FocusSignals) > 0 {
			fmt.Fprintf(output, "    关注信号：%s\n", strings.Join(decision.FocusSignals, "；"))
		} else if len(decision.Signals) > 0 {
			descriptions := make([]string, 0, len(decision.Signals))
			for _, signal := range decision.Signals {
				descriptions = append(descriptions, signal.Description)
			}
			fmt.Fprintf(output, "    世界信号：%s\n", strings.Join(descriptions, "；"))
		}
	}
	if !showAll && len(decisions) > 1 {
		fmt.Fprintf(output, "  还有 %d 条历史决策；输入 director all 查看全部。\n", len(decisions)-1)
	}
}

func directorSourceLabel(source string) string {
	if source == "deterministic" {
		return "确定性规则"
	}
	return "AI 模型"
}

func resolveActor(selector string, actors []app.VisibleActor, debug bool) (app.VisibleActor, error) {
	if number, err := strconv.Atoi(selector); err == nil {
		if number < 1 || number > len(actors) {
			return app.VisibleActor{}, fmt.Errorf("人物编号应在 1 到 %d 之间", len(actors))
		}
		return actors[number-1], nil
	}
	for _, actor := range actors {
		if selector == actor.Name || (debug && selector == actor.ID) {
			return actor, nil
		}
	}
	return app.VisibleActor{}, fmt.Errorf("当前地点没有人物 %q", selector)
}

func renderActorActions(output io.Writer, actions []app.AvailableAction, actorID string) []app.AvailableAction {
	return renderActorActionsSuggested(output, actions, actorID, nil)
}

func renderActorActionsSuggested(output io.Writer, actions []app.AvailableAction, actorID string, suggestions []string) []app.AvailableAction {
	actorActions := make([]app.AvailableAction, 0)
	for _, action := range terminalSelectableActions(actions) {
		if action.TargetID == actorID {
			actorActions = append(actorActions, action)
		}
	}
	found := false
	suggested := make(map[string]bool, len(suggestions))
	for _, actionID := range suggestions {
		suggested[actionID] = true
	}
	for index, action := range actorActions {
		if !found {
			fmt.Fprintln(output, "可选交涉：")
			found = true
		}
		marker := ""
		if suggested[action.ID] {
			marker = " [模型建议]"
		}
		fmt.Fprintf(output, "  %d. %s%s — %s\n", index+1, action.Name, marker, action.Description)
	}
	if !found {
		fmt.Fprintln(output, "当前没有需要通过规则结算的交涉选项。")
	} else {
		fmt.Fprintln(output, "输入 do <编号> 执行交涉。")
	}
	return actorActions
}

func renderMap(output io.Writer, view app.PlayerView, debug bool) {
	renderMapMode(output, view, debug, false)
}

func renderMapMode(output io.Writer, view app.PlayerView, debug, showAll bool) {
	mapTitle := view.Presentation.WorldTitle
	if mapTitle == "" {
		mapTitle = "世界地图"
	}
	fmt.Fprintf(output, "\n【%s】\n", mapTitle)
	for index, location := range view.WorldMap.Locations {
		marker := " "
		if location.Current {
			marker = "*"
		}
		id := ""
		if debug {
			id = " [" + location.ID + "]"
		}
		fmt.Fprintf(output, " %s %d. %s%s · 可见人物 %d\n", marker, index+1, location.Name, id, location.ActorCount)
	}
	if showAll {
		fmt.Fprintln(output, "全部已知路线：")
	} else {
		fmt.Fprintln(output, "当前位置可用路线：")
	}
	routeCount := 0
	for _, route := range view.WorldMap.Routes {
		if !showAll && route.FromID != view.Location.ID {
			continue
		}
		routeCount++
		from := mapLocationName(view, route.FromID)
		to := mapLocationName(view, route.ToID)
		status := mapRouteStatusLabel(route.Status)
		if route.ActionID != "" {
			status = "可前往"
		} else if len(route.Blockers) > 0 {
			status = "受阻：" + strings.Join(route.Blockers, "、")
		}
		fmt.Fprintf(output, "  - %s → %s：%d 天，危险 %d，%s\n", from, to, route.Duration, route.Danger, status)
	}
	if routeCount == 0 {
		fmt.Fprintln(output, "  当前没有已知路线。")
	}
	if showAll {
		fmt.Fprintln(output, "输入 go <地点名或地点编号> 移动。")
	} else {
		fmt.Fprintln(output, "输入 go <地点名或地点编号> 移动；输入 map all 查看全部已知路线。")
	}
}

func mapRouteStatusLabel(status string) string {
	switch status {
	case "known":
		return "已知路线"
	case "blocked":
		return "尚未开放"
	case "available":
		return "可前往"
	default:
		return status
	}
}

func mapLocationName(view app.PlayerView, id string) string {
	for _, location := range view.WorldMap.Locations {
		if location.ID == id {
			return location.Name
		}
	}
	return id
}

func renderJournal(output io.Writer, view app.PlayerView, debug bool) {
	fmt.Fprintln(output, "\n【卷宗】")
	fmt.Fprintln(output, presentationText(view, "preparation_heading", "当前准备"))
	fmt.Fprintf(output, "综合准备：%d / 基线 %d · %s\n", view.Preparation.TotalScore, view.Preparation.TargetScore, view.Preparation.Rating)
	if view.Preparation.RatingDetail != "" {
		fmt.Fprintf(output, "  %s\n", view.Preparation.RatingDetail)
	}
	if len(view.Preparation.ScoreSources) > 0 {
		fmt.Fprintln(output, "准备项：")
		for _, factor := range view.Preparation.ScoreSources {
			fmt.Fprintf(output, "  - %s：%d（%s）\n", factor.Label, factor.Value, factor.Status)
		}
	}
	if len(view.Preparation.Conditions) > 0 {
		fmt.Fprintln(output, "进入条件：")
		for _, factor := range view.Preparation.Conditions {
			if factor.Label == "" {
				continue
			}
			mark := "未满足"
			if factor.Ready {
				mark = "已满足"
			}
			fmt.Fprintf(output, "  - %s：%s\n", factor.Label, mark)
		}
	}
	for _, progress := range view.RouteProgresses {
		fmt.Fprintf(output, "当前路线：%s · %s\n", progress.Label, progress.Status)
		if progress.NextStep != "" {
			fmt.Fprintf(output, "  下一步：%s\n", progress.NextStep)
		}
	}
	if len(view.KnownFacts) > 0 {
		fmt.Fprintf(output, "已知%s：\n", presentationText(view, "term_clues", "线索"))
		for _, fact := range view.KnownFacts {
			id := ""
			if debug {
				id = " [" + fact.FactID + "]"
			}
			fmt.Fprintf(output, "  - %s%s（%s；来源：%s）\n", fact.Claim, id, confidenceLabel(fact.Confidence), sourceLabel(fact.Source))
		}
	}
	if len(view.CausalThreads) > 0 {
		fmt.Fprintf(output, "%s：\n", presentationText(view, "information_causal_heading", "你的影响"))
		for _, thread := range view.CausalThreads {
			fmt.Fprintf(output, "  - %s：%s\n", thread.ActorName, thread.Summary)
		}
	}
}

func resolveTravel(selector string, view app.PlayerView, debug bool) (string, error) {
	if selector == "" {
		return "", fmt.Errorf("请提供地点名或地图编号")
	}
	locationID := ""
	if number, err := strconv.Atoi(selector); err == nil {
		if number < 1 || number > len(view.WorldMap.Locations) {
			return "", fmt.Errorf("地点编号应在 1 到 %d 之间", len(view.WorldMap.Locations))
		}
		locationID = view.WorldMap.Locations[number-1].ID
	} else {
		for _, location := range view.WorldMap.Locations {
			if selector == location.Name || (debug && selector == location.ID) {
				locationID = location.ID
				break
			}
		}
	}
	if locationID == "" {
		return "", fmt.Errorf("地图上没有地点 %q；输入 map 查看地点编号", selector)
	}
	if locationID == view.Location.ID {
		return "", fmt.Errorf("你已经在%s", view.Location.Name)
	}
	for _, action := range view.AvailableActions {
		if action.Kind == "move" && action.TargetID == locationID {
			return action.ID, nil
		}
	}
	for _, route := range view.WorldMap.Routes {
		if route.ToID == locationID || route.FromID == locationID {
			if len(route.Blockers) > 0 {
				return "", fmt.Errorf("路线尚未开放：%s", strings.Join(route.Blockers, "、"))
			}
		}
	}
	return "", fmt.Errorf("当前无法直接前往%s", mapLocationName(view, locationID))
}

func renderDialogueMode(output io.Writer, mode string) {
	switch {
	case strings.HasPrefix(mode, "anthropic:"):
		fmt.Fprintf(output, "人物对话与世界导演：AI 已启用（%s）\n", strings.TrimPrefix(mode, "anthropic:"))
	case strings.HasPrefix(mode, "disabled"):
		fmt.Fprintln(output, "人物对话：未启用")
	default:
		fmt.Fprintln(output, "人物对话：配置异常")
	}
}

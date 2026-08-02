// Command play runs the player-facing interactive terminal client.
package main

import (
	"bufio"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"fantu/internal/ai"
	"fantu/internal/aiconfig"
	"fantu/internal/app"
	"fantu/internal/scenario"
)

func main() {
	if err := aiconfig.LoadDotEnv(".env"); err != nil {
		fail(err)
	}
	aiConfig := registerPlayAIFlags()
	dataDir := flag.String("data", filepath.FromSlash("data/blackwind"), "scenario data directory")
	playerName := flag.String("name", "无名散修", "new-game player name")
	loadPath := flag.String("load", "", "load an existing save file")
	autosavePath := flag.String("autosave", "", "save automatically after every turn")
	debug := flag.Bool("debug", false, "show stable IDs and internal metric details")
	flag.Parse()

	bundle, err := scenario.Load(*dataDir)
	if err != nil {
		fail(err)
	}

	var session *app.Session
	if *loadPath != "" {
		session, err = app.LoadFile(bundle, *loadPath)
	} else {
		session, err = app.NewSession(bundle, app.DefaultBlackwindPlayer(*playerName))
	}
	if err != nil {
		fail(err)
	}
	dialogue, dialogueMode, err := buildPlayDialogueService(aiConfig)
	if err != nil {
		fail(err)
	}
	renderDialogueMode(os.Stdout, dialogueMode)

	if err := runGame(os.Stdin, os.Stdout, session, dialogue, *autosavePath, *debug); err != nil {
		fail(err)
	}
}

func runGame(input io.Reader, output io.Writer, session *app.Session, dialogue *ai.Service, autosavePath string, debug bool) error {
	scanner := bufio.NewScanner(input)
	fmt.Fprintln(output, "凡途 · 黑风谷局势")
	fmt.Fprintln(output, "输入 help 查看命令；输入 actions 查看当前选择。")
	view := session.View()
	actionMenuCurrent := false
	var displayedActions []app.AvailableAction
	renderView(output, view, debug)

	for {
		if view.Resolved || view.Ended {
			return nil
		}

		fmt.Fprintf(output, "\n凡途[%s·第%d天]> ", view.Location.Name, view.Day)
		if !scanner.Scan() {
			if err := scanner.Err(); err != nil {
				return fmt.Errorf("read command: %w", err)
			}
			fmt.Fprintln(output, "\n已退出。")
			return nil
		}
		line := strings.TrimSpace(strings.TrimPrefix(scanner.Text(), "\ufeff"))
		switch {
		case line == "":
			continue
		case line == "q" || line == "quit" || line == "exit":
			fmt.Fprintln(output, "已退出。")
			return nil
		case line == "help" || line == "?":
			renderHelp(output, debug)
			continue
		case line == "look":
			renderLocation(output, view)
			continue
		case line == "people":
			renderPeople(output, view, debug)
			continue
		case line == "talk" || strings.HasPrefix(line, "talk "):
			displayedActions = renderTalk(output, session, dialogue, view, commandArgument(line), debug)
			actionMenuCurrent = len(displayedActions) > 0
			continue
		case line == "actions" || strings.HasPrefix(line, "actions "):
			var valid bool
			displayedActions, valid = renderActionsCategory(output, view.AvailableActions, commandArgument(line), debug)
			actionMenuCurrent = valid && len(displayedActions) > 0
			continue
		case line == "map" || line == "map all":
			renderMapMode(output, view, debug, line == "map all")
			continue
		case line == "journal":
			renderJournal(output, view, debug)
			continue
		case line == "wait" || line == "wait next" || line == "wait complete":
			actionID, err := waitCommand(line, view.AvailableActions)
			if err != nil {
				fmt.Fprintf(output, "无法等待：%v\n", err)
				continue
			}
			view, err = executeTerminalAction(output, session, actionID, autosavePath, debug)
			if err != nil {
				return err
			}
			actionMenuCurrent = false
			displayedActions = nil
			continue
		case line == "go" || strings.HasPrefix(line, "go "):
			actionID, err := resolveTravel(commandArgument(line), view, debug)
			if err != nil {
				fmt.Fprintf(output, "无法前往：%v\n", err)
				continue
			}
			view, err = executeTerminalAction(output, session, actionID, autosavePath, debug)
			if err != nil {
				return err
			}
			actionMenuCurrent = false
			displayedActions = nil
			continue
		case line == "save" || strings.HasPrefix(line, "save "):
			path := commandArgument(line)
			if path == "" {
				path = "save.json"
			}
			if err := saveSession(path, session); err != nil {
				fmt.Fprintf(output, "保存失败：%v\n", err)
			} else {
				fmt.Fprintf(output, "已保存到 %s\n", path)
			}
			continue
		case line == "do" || strings.HasPrefix(line, "do "):
			if !actionMenuCurrent {
				fmt.Fprintln(output, "行动目录尚未显示或已经变化；请先输入 actions，再使用 do <编号>。")
				continue
			}
			actionID, err := resolveActionNumber(commandArgument(line), displayedActions)
			if err != nil {
				fmt.Fprintf(output, "无法执行：%v\n", err)
				continue
			}
			view, err = executeTerminalAction(output, session, actionID, autosavePath, debug)
			if err != nil {
				return err
			}
			actionMenuCurrent = false
			displayedActions = nil
			continue
		}
		if _, err := strconv.Atoi(line); err == nil {
			fmt.Fprintf(output, "不能直接输入编号 %q；请先输入 actions，再使用 do %s。\n", line, line)
			continue
		}
		fmt.Fprintf(output, "未知命令 %q；输入 help 查看命令。\n", line)
	}
}

func commandArgument(line string) string {
	_, argument, _ := strings.Cut(line, " ")
	return strings.TrimSpace(argument)
}

func resolveActionNumber(input string, actions []app.AvailableAction) (string, error) {
	number, err := strconv.Atoi(input)
	if err != nil || number < 1 || number > len(actions) {
		return "", fmt.Errorf("行动编号不可用；请输入 actions 刷新目录，再选择 1 到 %d", len(actions))
	}
	return actions[number-1].ID, nil
}

func waitCommand(command string, actions []app.AvailableAction) (string, error) {
	if command == "wait" {
		return "wait", nil
	}
	wanted := "wait:next"
	if command == "wait complete" {
		wanted = "wait:complete"
	}
	for _, action := range actions {
		if action.ID == wanted {
			return action.ID, nil
		}
	}
	if wanted == "wait:complete" {
		return "", errors.New("当前没有正在进行的行动；使用 wait 等待一天，或 wait next 快进到下一变化")
	}
	return "", errors.New("当前不能快进到下一变化")
}

func executeTerminalAction(output io.Writer, session *app.Session, actionID, autosavePath string, debug bool) (app.PlayerView, error) {
	view, err := session.Execute(actionID)
	if err != nil {
		fmt.Fprintf(output, "行动失败：%v\n", err)
		return session.View(), nil
	}
	if autosavePath != "" {
		if err := saveSession(autosavePath, session); err != nil {
			return app.PlayerView{}, fmt.Errorf("autosave: %w", err)
		}
	}
	renderView(output, view, debug)
	if !view.Resolved && !view.Ended {
		renderActionRefresh(output, view.AvailableActions)
	}
	return view, nil
}

func renderView(output io.Writer, view app.PlayerView, debug bool) {
	fmt.Fprintf(output, "\n=== 第 %d/%d 天 · %s · %s ===\n", view.Day, view.Duration, phaseLabel(view.Phase), view.Location.Name)
	if view.LastTurn != nil {
		fmt.Fprintf(output, "上回合：%s [%s]\n", view.LastTurn.Action, statusLabel(view.LastTurn.Status))
		if view.LastTurn.DaysAdvanced > 1 {
			fmt.Fprintf(output, "  - 推进了 %d 天，其中 %d 天没有需要处理的变化。\n", view.LastTurn.DaysAdvanced, view.LastTurn.QuietDays)
		}
		for _, message := range view.LastTurn.Messages {
			fmt.Fprintf(output, "  - %s\n", message)
		}
		renderInfluences(output, view.LastTurn.Influence, debug, "情报回响")
	}
	if view.Resolved || view.Ended {
		fmt.Fprintf(output, "局势结束：%s\n", view.Outcome)
		if view.Ending != nil {
			fmt.Fprintln(output, "你的历程：")
			for _, highlight := range view.Ending.Highlights {
				fmt.Fprintf(output, "  - %s\n", highlight)
			}
			renderInfluences(output, view.Ending.Influence, debug, "关键影响")
			if len(view.Ending.PlayerConsequences) > 0 {
				fmt.Fprintln(output, "个人结果：")
				for _, consequence := range view.Ending.PlayerConsequences {
					fmt.Fprintf(output, "  - %s\n", consequence)
				}
			}
			if len(view.Ending.Review) > 0 {
				fmt.Fprintln(output, "胜负复盘：")
				for _, review := range view.Ending.Review {
					fmt.Fprintf(output, "  - %s\n", review)
				}
			}
		}
		fmt.Fprintf(output, "试玩记录：%d 次决策输入，%d 次主动行动，%d 次推进；自动略过 %d 天，核心结果产生于第 %d 天。\n",
			view.Metrics.DecisionInputs, view.Metrics.ActiveActions, view.Metrics.WaitActions, view.Metrics.AutoAdvancedDays, view.Metrics.CoreResultDay)
		if debug {
			fmt.Fprintf(output, "调试指标：最大行动目录=%d，最长空等待=%d，最大重复主动行动=%d，可见决策变化=%d，结果后输入=%d。\n",
				view.Metrics.MaxActionCatalog, view.Metrics.LongestQuietWait, view.Metrics.MaxRepeatedActiveAction,
				view.Metrics.VisibleDecisionChanges, view.Metrics.PostResultInputs)
		}
		return
	}

	resourceKeys := make([]string, 0, len(view.Player.Resources))
	for key := range view.Player.Resources {
		resourceKeys = append(resourceKeys, key)
	}
	sort.Strings(resourceKeys)
	resources := make([]string, 0, len(resourceKeys))
	for _, key := range resourceKeys {
		resources = append(resources, fmt.Sprintf("%s=%d", resourceLabel(key), view.Player.Resources[key]))
	}
	fmt.Fprintf(output, "%s｜伤势 %d｜%s\n", view.Player.Name, view.Player.Injury, strings.Join(resources, "  "))

	if len(view.Player.Items) > 0 {
		items := make([]string, 0, len(view.Player.Items))
		for _, item := range view.Player.Items {
			items = append(items, fmt.Sprintf("%s×%d", item.Name, item.Amount))
		}
		fmt.Fprintf(output, "物品：%s\n", strings.Join(items, "、"))
	}
	if view.Player.Busy {
		fmt.Fprintf(output, "状态：%s（第 %d 天完成）\n", view.Player.BusyAction, view.Player.BusyUntil)
	}
	if len(view.KnownFacts) > 0 {
		fmt.Fprintln(output, "线索：")
		for _, belief := range view.KnownFacts {
			id := ""
			if debug {
				id = belief.FactID + " "
			}
			fmt.Fprintf(output, "  %s[%s] %s（来源：%s）\n", id, confidenceLabel(belief.Confidence), belief.Claim, sourceLabel(belief.Source))
		}
	}
	if len(view.KnownActors) > 0 {
		names := make([]string, 0, len(view.KnownActors))
		for _, actor := range view.KnownActors {
			names = append(names, actor.Name)
		}
		fmt.Fprintf(output, "同地人物：%s\n", strings.Join(names, "、"))
	}
	if len(view.Guidance) > 0 {
		fmt.Fprintln(output, "当前提示：")
		for _, guidance := range view.Guidance {
			fmt.Fprintf(output, "  - %s\n", guidance)
		}
	}
	if view.Travel != nil {
		fmt.Fprintf(output, "行程判断：前往%s预计需要 %d 天。\n", view.Travel.Destination, view.Travel.TravelDays)
		if view.Travel.Ready {
			fmt.Fprintln(output, "  - 当前通行条件已满足。")
		} else {
			fmt.Fprintf(output, "  - 尚未满足：%s。\n", strings.Join(view.Travel.Blockers, "、"))
		}
		if view.Travel.Timing != "" {
			fmt.Fprintln(output, "  - "+view.Travel.Timing)
		}
	}
}

func renderActions(output io.Writer, actions []app.AvailableAction, debug bool) {
	renderActionsCategory(output, actions, "", debug)
}

func renderActionsCategory(output io.Writer, actions []app.AvailableAction, requested string, debug bool) ([]app.AvailableAction, bool) {
	selectable := terminalSelectableActions(actions)
	category, valid := normalizeActionCategory(requested)
	if !valid {
		fmt.Fprintf(output, "未知行动类别 %q；可用类别：调查、交涉、准备、出行。\n", requested)
		return nil, false
	}
	displayed := make([]app.AvailableAction, 0, len(selectable))
	for _, action := range selectable {
		if category == "" || terminalActionCategory(action) == category {
			displayed = append(displayed, action)
		}
	}
	fmt.Fprintln(output, "可用行动：")
	found := false
	lastCategory := ""
	for index, action := range displayed {
		currentCategory := terminalActionCategory(action)
		found = true
		if currentCategory != lastCategory {
			fmt.Fprintf(output, " [%s]\n", terminalActionCategoryLabel(currentCategory))
			lastCategory = currentCategory
		}
		cost := ""
		if len(action.Costs) > 0 {
			parts := make([]string, 0, len(action.Costs))
			for key, amount := range action.Costs {
				parts = append(parts, fmt.Sprintf("%s %d", resourceLabel(key), amount))
			}
			sort.Strings(parts)
			cost = "；花费 " + strings.Join(parts, "、")
		}
		id := ""
		if debug {
			id = " [" + action.ID + "]"
		}
		duration := fmt.Sprintf("%d 天", action.Duration)
		fmt.Fprintf(output, "  %d. %s%s — %s（%s%s）\n", index+1, action.Name, id, action.Description, duration, cost)
	}
	if !found {
		fmt.Fprintln(output, "  当前没有该类别的可执行行动。")
	}
	if len(actions) != len(selectable) {
		fmt.Fprintln(output, "时间推进：wait 等待一天；wait complete 完成当前行动；wait next 快进到下一重要变化。")
	}
	return displayed, true
}

func terminalSelectableActions(actions []app.AvailableAction) []app.AvailableAction {
	result := make([]app.AvailableAction, 0, len(actions))
	for _, action := range actions {
		if action.Kind != "advance" {
			result = append(result, action)
		}
	}
	return result
}

func normalizeActionCategory(value string) (string, bool) {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "":
		return "", true
	case "调查", "investigate", "investigation":
		return "investigate", true
	case "交涉", "talk", "social", "information":
		return "interact", true
	case "准备", "prepare", "preparation":
		return "prepare", true
	case "出行", "travel", "move":
		return "travel", true
	default:
		return "", false
	}
}

func terminalActionCategory(action app.AvailableAction) string {
	switch action.Kind {
	case "verify":
		return "investigate"
	case "tell", "route":
		return "interact"
	case "move":
		return "travel"
	default:
		return "prepare"
	}
}

func terminalActionCategoryLabel(category string) string {
	switch category {
	case "investigate":
		return "调查"
	case "interact":
		return "交涉"
	case "travel":
		return "出行"
	default:
		return "准备"
	}
}

func renderActionRefresh(output io.Writer, actions []app.AvailableAction) {
	selectable := terminalSelectableActions(actions)
	counts := make(map[string]int)
	for _, action := range selectable {
		counts[terminalActionCategory(action)]++
	}
	parts := make([]string, 0, 4)
	for _, category := range []string{"investigate", "interact", "prepare", "travel"} {
		if counts[category] > 0 {
			parts = append(parts, fmt.Sprintf("%s %d", terminalActionCategoryLabel(category), counts[category]))
		}
	}
	if len(parts) == 0 {
		fmt.Fprintln(output, "行动目录已刷新：当前只能推进时间。")
		return
	}
	fmt.Fprintf(output, "行动目录已刷新：%d 项（%s）。旧编号已失效，请重新输入 actions 或 actions <类别>。\n", len(selectable), strings.Join(parts, "、"))
}

func renderInfluences(output io.Writer, influences []app.VisibleInfluence, debug bool, title string) {
	if len(influences) == 0 {
		return
	}
	fmt.Fprintln(output, title+"：")
	for _, influence := range influences {
		fact := "这条情报"
		if influence.FactClaim != "" {
			fact = "“" + influence.FactClaim + "”"
		}
		if debug {
			fact += " [" + influence.FactID + "]"
		}
		fmt.Fprintf(output, "  - 第 %d 天，你把%s告诉了%s。\n", influence.DeliveredDay, fact, influence.ActorName)
		for _, change := range influence.Changes {
			fmt.Fprintf(output, "    第 %d 天：原本会“%s”，现在改为“%s”。\n", change.Day, change.WithoutInformation, change.WithInformation)
		}
	}
}

func resourceLabel(key string) string {
	switch key {
	case "combat":
		return "战力"
	case "support":
		return "支援"
	case "spirit_stones":
		return "灵石"
	case "credit":
		return "信誉"
	default:
		return key
	}
}

func statusLabel(status string) string {
	switch status {
	case "started":
		return "已开始"
	case "progressing":
		return "进行中"
	case "completed":
		return "已完成"
	default:
		return status
	}
}

func sourceLabel(source string) string {
	switch source {
	case "player-investigation":
		return "亲自核验"
	case "player-investigation-lead":
		return "调查所得线索"
	default:
		return source
	}
}

func phaseLabel(phase string) string {
	if phase == "" {
		return "序幕"
	}
	return phase
}

func confidenceLabel(value int) string {
	switch value {
	case 3:
		return "已核实"
	case 2:
		return "较可信"
	case 1:
		return "传闻"
	default:
		return "未知"
	}
}

func renderHelp(output io.Writer, debug bool) {
	if debug {
		fmt.Fprintln(output, "命令：look；people；talk <编号|人物ID|姓名>（一次回应）；actions [调查|交涉|准备|出行]；do <行动编号>；map [all]；go <地点>；journal；wait；wait complete；wait next；save [文件]；quit。")
		return
	}
	fmt.Fprintln(output, "命令：look；people；talk <人物编号或姓名>（一次回应）；actions [调查|交涉|准备|出行]；do <行动编号>；map [all]；go <地点>；journal；wait；wait complete；wait next；save [文件]；quit。")
}

func saveSession(path string, session *app.Session) error {
	if strings.TrimSpace(path) == "" {
		return errors.New("save path is empty")
	}
	return session.SaveFile(path)
}

func fail(err error) {
	fmt.Fprintln(os.Stderr, "play:", err)
	os.Exit(1)
}

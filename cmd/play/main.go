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
			renderTalk(output, session, dialogue, view, commandArgument(line), debug)
			continue
		case line == "actions":
			renderActions(output, view.AvailableActions, debug)
			continue
		case line == "map":
			renderMap(output, view, debug)
			continue
		case line == "journal":
			renderJournal(output, view, debug)
			continue
		case line == "wait":
			actionID, err := waitAction(view.AvailableActions, view.Player.Busy)
			if err != nil {
				fmt.Fprintf(output, "无法等待：%v\n", err)
				continue
			}
			view, err = executeTerminalAction(output, session, actionID, autosavePath, debug)
			if err != nil {
				return err
			}
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
			actionID, err := resolveActionNumber(commandArgument(line), view.AvailableActions)
			if err != nil {
				fmt.Fprintf(output, "无法执行：%v\n", err)
				continue
			}
			view, err = executeTerminalAction(output, session, actionID, autosavePath, debug)
			if err != nil {
				return err
			}
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
		return "", fmt.Errorf("请提供 1 到 %d 之间的行动编号", len(actions))
	}
	return actions[number-1].ID, nil
}

func waitAction(actions []app.AvailableAction, busy bool) (string, error) {
	wanted := "wait:next"
	if busy {
		wanted = "wait:complete"
	}
	for _, action := range actions {
		if action.ID == wanted {
			return action.ID, nil
		}
	}
	return "", errors.New("当前没有可用的时间推进选项")
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
	fmt.Fprintln(output, "可用行动：")
	for index, action := range actions {
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
		if action.ID == "wait:next" {
			duration = "到下一变化"
		} else if action.ID == "wait:complete" {
			duration = fmt.Sprintf("最多 %d 天", action.Duration)
		}
		fmt.Fprintf(output, "  %d. %s%s — %s（%s%s）\n", index+1, action.Name, id, action.Description, duration, cost)
	}
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
		fmt.Fprintln(output, "命令：look；people；talk <编号|人物ID|姓名>；actions；do <行动编号>；map；go <地点>；journal；wait；save [文件]；quit。")
		return
	}
	fmt.Fprintln(output, "命令：look；people；talk <人物编号或姓名>；actions；do <行动编号>；map；go <地点>；journal；wait；save [文件]；quit。")
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

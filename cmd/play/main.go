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

	"fantu/internal/app"
	"fantu/internal/domain"
	"fantu/internal/scenario"
)

func main() {
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
		file, openErr := os.Open(*loadPath)
		if openErr != nil {
			fail(openErr)
		}
		session, err = app.LoadSession(bundle, file)
		closeErr := file.Close()
		if err == nil {
			err = closeErr
		}
	} else {
		session, err = app.NewSession(bundle, defaultPlayer(*playerName))
	}
	if err != nil {
		fail(err)
	}

	if err := run(os.Stdin, os.Stdout, session, *autosavePath, *debug); err != nil {
		fail(err)
	}
}

func defaultPlayer(name string) domain.PlayerConfig {
	return domain.PlayerConfig{
		ID: "P00", Name: name, Location: "L01",
		Resources: map[string]int{"combat": 2, "support": 0, "spirit_stones": 100, "credit": 3},
		Items:     []string{"healing_pill"},
		Beliefs: []domain.Belief{{
			FactID: "F02", Claim: "青髓芝将在第24天成熟", Confidence: 1,
			Source: "坊市传言", LearnedOn: 0, Secrecy: 0,
		}},
	}
}

func run(input io.Reader, output io.Writer, session *app.Session, autosavePath string, debug bool) error {
	scanner := bufio.NewScanner(input)
	fmt.Fprintln(output, "凡途 · 黑风谷局势")
	fmt.Fprintln(output, "输入行动编号推进局势；输入 help 查看命令。")

	for {
		view := session.View()
		renderView(output, view, debug)
		if view.Resolved || view.Ended {
			return nil
		}

		fmt.Fprint(output, "\n选择> ")
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
		case line == "save" || strings.HasPrefix(line, "save "):
			path := strings.TrimSpace(strings.TrimPrefix(line, "save"))
			if path == "" {
				path = "save.json"
			}
			if err := saveSession(path, session); err != nil {
				fmt.Fprintf(output, "保存失败：%v\n", err)
			} else {
				fmt.Fprintf(output, "已保存到 %s\n", path)
			}
			continue
		}

		actionID, err := resolveAction(line, view.AvailableActions)
		if err != nil {
			fmt.Fprintf(output, "无法执行：%v\n", err)
			continue
		}
		if _, err := session.Execute(actionID); err != nil {
			fmt.Fprintf(output, "行动失败：%v\n", err)
			continue
		}
		if autosavePath != "" {
			if err := saveSession(autosavePath, session); err != nil {
				return fmt.Errorf("autosave: %w", err)
			}
		}
	}
}

func resolveAction(input string, actions []app.AvailableAction) (string, error) {
	if number, err := strconv.Atoi(input); err == nil {
		if number < 1 || number > len(actions) {
			return "", fmt.Errorf("编号应在 1 到 %d 之间", len(actions))
		}
		return actions[number-1].ID, nil
	}
	for _, action := range actions {
		if input == action.ID {
			return action.ID, nil
		}
	}
	return "", fmt.Errorf("未知行动 %q", input)
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
	fmt.Fprintln(output, "可用行动：")
	for index, action := range view.AvailableActions {
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
		fmt.Fprintln(output, "命令：<编号> 或 <行动ID> 执行动作；wait 逐日推进；save [文件] 保存；quit 退出。")
		return
	}
	fmt.Fprintln(output, "命令：输入行动编号；save [文件] 保存；quit 退出。")
}

func saveSession(path string, session *app.Session) error {
	if strings.TrimSpace(path) == "" {
		return errors.New("save path is empty")
	}
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	file, err := os.Create(path)
	if err != nil {
		return err
	}
	saveErr := session.Save(file)
	closeErr := file.Close()
	if saveErr != nil {
		return saveErr
	}
	return closeErr
}

func fail(err error) {
	fmt.Fprintln(os.Stderr, "play:", err)
	os.Exit(1)
}

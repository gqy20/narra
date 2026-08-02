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
	"time"

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
	saveDir := flag.String("saves", "saves", "directory containing named save slots")
	loadSlot := flag.String("load", "", "load a named save slot")
	autosave := flag.Bool("autosave", true, "save to the autosave slot after every turn")
	debug := flag.Bool("debug", false, "show stable IDs and internal metric details")
	flag.Parse()

	bundle, err := scenario.Load(*dataDir)
	if err != nil {
		fail(err)
	}

	store, err := newTerminalSaveStore(*saveDir, bundle)
	if err != nil {
		fail(err)
	}

	var session *app.Session
	if *loadSlot != "" {
		session, err = store.load(*loadSlot)
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

	game := &terminalGame{session: session, saves: store, autosave: *autosave}
	if err := runGame(os.Stdin, os.Stdout, game, dialogue, *debug); err != nil {
		fail(err)
	}
}

func runGame(input io.Reader, output io.Writer, game *terminalGame, dialogue *ai.Service, debug bool) error {
	session := game.session
	commands := scanTerminalCommands(input)
	fmt.Fprintln(output, "凡途 · 黑风谷局势")
	fmt.Fprintln(output, "输入 help 查看命令；输入 actions 查看当前选择。")
	if game.saves != nil {
		if game.autosave {
			fmt.Fprintf(output, "自动存档已开启：每次成功行动后写入 %s 槽。\n", autosaveSlot)
		} else {
			fmt.Fprintln(output, "自动存档已关闭；可输入 autosave on 开启。")
		}
	}
	view := session.View()
	actionMenuCurrent := false
	var displayedActions []app.AvailableAction
	var conversation *terminalDialogueSession
	var pendingDialogue *terminalDialogueRequest
	var retryDialogue *terminalDialogueAttempt
	var queuedCommands []terminalCommand
	var nextDialogueRequestID uint64
	inputPaused := false
	renderView(output, view, debug)

	for {
		if view.Resolved || view.Ended {
			return nil
		}

		if pendingDialogue != nil {
			commandSource := commands
			if inputPaused {
				commandSource = nil
			}
			select {
			case generated := <-pendingDialogue.result:
				request := pendingDialogue
				stopDialogueRequest(request)
				pendingDialogue = nil
				inputPaused = false
				if generated.requestID != request.id {
					fmt.Fprintln(output, "已忽略过期的模型回应。")
					continue
				}
				if generated.err != nil {
					fmt.Fprintf(output, "对话生成失败：%v\n", generated.err)
					attempt := request.attempt
					retryDialogue = &attempt
					fmt.Fprintln(output, "输入 retry 重试，或 leave 结束对话。")
					continue
				}
				if game.session.DialogueRevision(request.attempt.actor.ID) != request.attempt.snapshot.Revision {
					fmt.Fprintln(output, "局势已经变化，已丢弃过期的模型回应。")
					retryDialogue = nil
					conversation = nil
					continue
				}
				if err := recordDialogueTurn(game, request.attempt.snapshot, request.attempt.playerText, generated.line); err != nil {
					fmt.Fprintf(output, "保存对话失败：%v\n", err)
					attempt := request.attempt
					retryDialogue = &attempt
					continue
				}
				renderDialogueReply(output, request.attempt.actor, request.attempt.snapshot, generated.line, debug)
				displayedActions = renderActorActionsSuggested(output, game.session.View().AvailableActions, request.attempt.actor.ID, generated.line.SuggestedActions)
				actionMenuCurrent = len(displayedActions) > 0
				retryDialogue = nil
				if request.attempt.opening {
					fmt.Fprintln(output, "已进入对话：直接输入回复；context 查看语境；actions 查看交涉；cancel 取消生成；leave 离开。")
				}
				continue
			case <-pendingDialogue.ticker.C:
				fmt.Fprintf(output, "  已等待 %d 秒，仍在等待模型返回……\n", int(time.Since(pendingDialogue.started).Seconds()))
				continue
			case command, ok := <-commandSource:
				if !ok {
					commands = nil
					inputPaused = true
					continue
				}
				if command.err != nil {
					stopDialogueRequest(pendingDialogue)
					return command.err
				}
				line := command.line
				switch {
				case line == "cancel":
					attempt := pendingDialogue.attempt
					stopDialogueRequest(pendingDialogue)
					pendingDialogue = nil
					retryDialogue = &attempt
					queuedCommands = nil
					inputPaused = false
					fmt.Fprintln(output, "已取消本次模型生成；输入 retry 可重新提交。")
				case line == "leave":
					stopDialogueRequest(pendingDialogue)
					pendingDialogue = nil
					retryDialogue = nil
					queuedCommands = nil
					inputPaused = false
					if conversation != nil {
						fmt.Fprintf(output, "已取消生成并结束与%s的对话。\n", conversation.actor.Name)
					}
					conversation = nil
					actionMenuCurrent = false
					displayedActions = nil
				case line == "context":
					if conversation != nil {
						renderDialogueContext(output, session, conversation)
					}
					fmt.Fprintf(output, "模型请求 %d 已等待 %d 秒。\n", pendingDialogue.id, int(time.Since(pendingDialogue.started).Seconds()))
				case line == "await":
					inputPaused = true
					fmt.Fprintf(output, "等待模型请求 %d 完成。\n", pendingDialogue.id)
				case line == "retry":
					fmt.Fprintln(output, "当前请求仍在生成；请先 cancel，再输入 retry。")
				case line == "q" || line == "quit" || line == "exit":
					stopDialogueRequest(pendingDialogue)
					fmt.Fprintln(output, "已取消生成并退出。")
					return nil
				default:
					queuedCommands = append(queuedCommands, command)
					fmt.Fprintln(output, "模型仍在生成；这条输入将在回应完成后处理。仍可输入 cancel 取消当前生成并清空排队输入。")
				}
				continue
			}
		}

		var command terminalCommand
		if len(queuedCommands) > 0 {
			command = queuedCommands[0]
			queuedCommands = queuedCommands[1:]
		} else {
			if commands == nil {
				fmt.Fprintln(output, "\n已退出。")
				return nil
			}
			fmt.Fprintf(output, "\n凡途[%s·第%d天]> ", view.Location.Name, view.Day)
			var ok bool
			command, ok = <-commands
			if !ok {
				commands = nil
				continue
			}
			if command.err != nil {
				return command.err
			}
		}
		line := command.line
		if conversation != nil {
			switch {
			case line == "leave":
				fmt.Fprintf(output, "你结束了与%s的对话。\n", conversation.actor.Name)
				conversation = nil
				actionMenuCurrent = false
				displayedActions = nil
				continue
			case line == "context":
				renderDialogueContext(output, session, conversation)
				continue
			case line == "actions":
				displayedActions = renderActorActions(output, view.AvailableActions, conversation.actor.ID)
				actionMenuCurrent = len(displayedActions) > 0
				continue
			case line != "" && !isTerminalCommand(line):
				attempt := prepareDialogueTurn(output, game, conversation, line)
				if attempt == nil {
					conversation = nil
					continue
				}
				nextDialogueRequestID++
				pendingDialogue = beginDialogueRequest(output, game.session, dialogue, *attempt, nextDialogueRequestID)
				continue
			}
		}
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
			var attempt *terminalDialogueAttempt
			conversation, attempt = prepareDialogueStart(output, game, dialogue, view, commandArgument(line), debug)
			if attempt != nil {
				nextDialogueRequestID++
				pendingDialogue = beginDialogueRequest(output, game.session, dialogue, *attempt, nextDialogueRequestID)
			}
			continue
		case line == "retry":
			if retryDialogue == nil || conversation == nil {
				fmt.Fprintln(output, "当前没有可重试的模型请求。")
				continue
			}
			if game.session.DialogueRevision(retryDialogue.actor.ID) != retryDialogue.snapshot.Revision {
				fmt.Fprintln(output, "局势已经变化，无法重试旧请求；请重新使用 talk。")
				retryDialogue = nil
				conversation = nil
				continue
			}
			nextDialogueRequestID++
			fmt.Fprintln(output, "正在重新提交上次模型请求。")
			pendingDialogue = beginDialogueRequest(output, game.session, dialogue, *retryDialogue, nextDialogueRequestID)
			continue
		case line == "cancel":
			fmt.Fprintln(output, "当前没有正在生成的模型请求。")
			continue
		case line == "await":
			fmt.Fprintln(output, "当前没有需要等待的模型请求。")
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
		case line == "wait next":
			renderWaitNextPreview(output, view)
			continue
		case line == "wait" || line == "wait next confirm" || line == "wait complete":
			actionID, err := waitCommand(line, view.AvailableActions)
			if err != nil {
				fmt.Fprintf(output, "无法等待：%v\n", err)
				continue
			}
			view, err = executeTerminalAction(output, game, actionID, debug)
			if err != nil {
				return err
			}
			actionMenuCurrent = false
			displayedActions = nil
			conversation = nil
			retryDialogue = nil
			continue
		case line == "go" || strings.HasPrefix(line, "go "):
			actionID, err := resolveTravel(commandArgument(line), view, debug)
			if err != nil {
				fmt.Fprintf(output, "无法前往：%v\n", err)
				continue
			}
			view, err = executeTerminalAction(output, game, actionID, debug)
			if err != nil {
				return err
			}
			actionMenuCurrent = false
			displayedActions = nil
			conversation = nil
			retryDialogue = nil
			continue
		case line == "saves":
			renderSaveSlots(output, game.saves)
			continue
		case line == "autosave" || strings.HasPrefix(line, "autosave "):
			renderAutosaveCommand(output, game, commandArgument(line))
			continue
		case line == "load" || strings.HasPrefix(line, "load "):
			loaded, err := loadSaveCommand(output, game, commandArgument(line))
			if err != nil {
				fmt.Fprintf(output, "读取失败：%v\n", err)
				continue
			}
			if !loaded {
				continue
			}
			session = game.session
			view = session.View()
			actionMenuCurrent = false
			displayedActions = nil
			conversation = nil
			retryDialogue = nil
			renderView(output, view, debug)
			continue
		case line == "save" || strings.HasPrefix(line, "save "):
			if err := saveSlotCommand(output, game, commandArgument(line)); err != nil {
				fmt.Fprintf(output, "保存失败：%v\n", err)
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
			view, err = executeTerminalAction(output, game, actionID, debug)
			if err != nil {
				return err
			}
			actionMenuCurrent = false
			displayedActions = nil
			conversation = nil
			retryDialogue = nil
			continue
		}
		if _, err := strconv.Atoi(line); err == nil {
			fmt.Fprintf(output, "不能直接输入编号 %q；请先输入 actions，再使用 do %s。\n", line, line)
			continue
		}
		fmt.Fprintf(output, "未知命令 %q；输入 help 查看命令。\n", line)
	}
}

type terminalCommand struct {
	line string
	err  error
}

func scanTerminalCommands(input io.Reader) <-chan terminalCommand {
	commands := make(chan terminalCommand)
	go func() {
		defer close(commands)
		scanner := bufio.NewScanner(input)
		for scanner.Scan() {
			commands <- terminalCommand{line: strings.TrimSpace(strings.TrimPrefix(scanner.Text(), "\ufeff"))}
		}
		if err := scanner.Err(); err != nil {
			commands <- terminalCommand{err: fmt.Errorf("read command: %w", err)}
		}
	}()
	return commands
}

func isTerminalCommand(line string) bool {
	command := line
	if before, _, found := strings.Cut(line, " "); found {
		command = before
	}
	switch command {
	case "q", "quit", "exit", "help", "?", "look", "people", "talk", "actions", "map", "journal", "wait", "go", "saves", "autosave", "load", "save", "do", "context", "leave", "cancel", "retry", "await":
		return true
	default:
		return false
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

func executeTerminalAction(output io.Writer, game *terminalGame, actionID string, debug bool) (app.PlayerView, error) {
	view, err := game.session.Execute(actionID)
	if err != nil {
		fmt.Fprintf(output, "行动失败：%v\n", err)
		return game.session.View(), nil
	}
	if game.autosave && game.saves != nil {
		if err := game.saves.save(autosaveSlot, game.session); err != nil {
			return app.PlayerView{}, fmt.Errorf("autosave: %w", err)
		}
	}
	renderView(output, view, debug)
	if !view.Resolved && !view.Ended {
		renderActionRefresh(output, view.AvailableActions)
	}
	return view, nil
}

func renderWaitNextPreview(output io.Writer, view app.PlayerView) {
	var waitAction *app.AvailableAction
	for index := range view.AvailableActions {
		if view.AvailableActions[index].ID == "wait:next" {
			waitAction = &view.AvailableActions[index]
			break
		}
	}
	if waitAction == nil {
		fmt.Fprintln(output, "无法等待：当前不能快进到下一次重要变化。")
		return
	}
	fmt.Fprintf(output, "快进预览：当前第 %d 天；该操作会连续略过平静日，直到下一次重要变化。\n", view.Day)
	if waitAction.Timing != "" {
		fmt.Fprintln(output, "  - "+waitAction.Timing)
	}
	for _, warning := range waitAction.Warnings {
		fmt.Fprintln(output, "  - 风险："+warning)
	}
	for _, unknown := range waitAction.Unknowns {
		fmt.Fprintln(output, "  - 未知："+unknown)
	}
	if view.Travel != nil && view.Travel.Timing != "" {
		fmt.Fprintln(output, "  - "+view.Travel.Timing)
	}
	if view.RouteProgress != nil && view.RouteProgress.Window != "" {
		fmt.Fprintf(output, "  - 当前路线窗口：%s\n", view.RouteProgress.Window)
	}
	fmt.Fprintln(output, "确认后请输入 wait next confirm；也可用 wait 只等待一天。")
}

func saveSlotCommand(output io.Writer, game *terminalGame, argument string) error {
	if game.saves == nil {
		return errors.New("save store is unavailable")
	}
	fields := strings.Fields(argument)
	slot := defaultSaveSlot
	confirm := false
	if len(fields) > 0 {
		slot = fields[0]
	}
	if len(fields) > 1 && fields[1] == "confirm" {
		confirm = true
	}
	if len(fields) > 2 || (len(fields) > 1 && !confirm) {
		return errors.New("usage: save [slot] [confirm]")
	}
	exists, err := game.saves.exists(slot)
	if err != nil {
		return err
	}
	if exists && !confirm {
		fmt.Fprintf(output, "存档槽 %s 已存在；输入 save %s confirm 确认覆盖。\n", slot, slot)
		return nil
	}
	if err := game.saves.save(slot, game.session); err != nil {
		return err
	}
	fmt.Fprintf(output, "已保存到存档槽 %s。\n", slot)
	return nil
}

func loadSaveCommand(output io.Writer, game *terminalGame, argument string) (bool, error) {
	if game.saves == nil {
		return false, errors.New("save store is unavailable")
	}
	fields := strings.Fields(argument)
	if len(fields) == 0 || len(fields) > 2 {
		return false, errors.New("usage: load <slot> [confirm]")
	}
	confirm := len(fields) == 2 && fields[1] == "confirm"
	if len(fields) == 2 && !confirm {
		return false, errors.New("usage: load <slot> [confirm]")
	}
	if !game.autosave && !confirm {
		fmt.Fprintf(output, "自动存档已关闭；输入 load %s confirm 确认放弃当前未保存进度。\n", fields[0])
		return false, nil
	}
	loaded, err := game.saves.load(fields[0])
	if err != nil {
		return false, err
	}
	game.session = loaded
	fmt.Fprintf(output, "已读取存档槽 %s。\n", fields[0])
	return true, nil
}

func renderSaveSlots(output io.Writer, store *terminalSaveStore) {
	if store == nil {
		fmt.Fprintln(output, "存档系统不可用。")
		return
	}
	infos, err := store.list()
	if err != nil {
		fmt.Fprintf(output, "读取存档列表失败：%v\n", err)
		return
	}
	if len(infos) == 0 {
		fmt.Fprintln(output, "尚无存档。")
		return
	}
	fmt.Fprintln(output, "存档槽：")
	for _, info := range infos {
		fmt.Fprintf(output, "  - %s：第 %d 天 · %s · %s\n", info.Slot, info.Day, info.Location, info.Modified.Format("2006-01-02 15:04"))
	}
}

func renderAutosaveCommand(output io.Writer, game *terminalGame, argument string) {
	switch strings.ToLower(strings.TrimSpace(argument)) {
	case "":
		state := "关闭"
		if game.autosave {
			state = "开启"
		}
		fmt.Fprintf(output, "自动存档：%s（槽位 %s）。\n", state, autosaveSlot)
	case "on":
		game.autosave = true
		fmt.Fprintf(output, "自动存档已开启，将在每次成功行动后写入 %s。\n", autosaveSlot)
	case "off":
		game.autosave = false
		fmt.Fprintln(output, "自动存档已关闭。")
	default:
		fmt.Fprintln(output, "用法：autosave [on|off]")
	}
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
	query, err := parseActionQuery(requested)
	if err != nil {
		fmt.Fprintf(output, "行动查询无效：%v\n", err)
		return nil, false
	}
	filtered := make([]app.AvailableAction, 0, len(selectable))
	for _, action := range selectable {
		if query.category != "" && terminalActionCategory(action) != query.category {
			continue
		}
		if query.search != "" && !actionMatchesSearch(action, query.search) {
			continue
		}
		filtered = append(filtered, action)
	}
	const pageSize = 8
	pageCount := (len(filtered) + pageSize - 1) / pageSize
	if pageCount == 0 {
		pageCount = 1
	}
	if query.page > pageCount {
		fmt.Fprintf(output, "页码超出范围；当前查询共 %d 页。\n", pageCount)
		return nil, false
	}
	start := (query.page - 1) * pageSize
	end := start + pageSize
	if end > len(filtered) {
		end = len(filtered)
	}
	displayed := filtered[start:end]
	fmt.Fprintf(output, "可用行动（第 %d/%d 页，共 %d 项）：\n", query.page, pageCount, len(filtered))
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
		fmt.Fprintln(output, "  当前没有符合条件的可执行行动。")
	}
	if query.page < pageCount {
		fmt.Fprintf(output, "下一页：%s\n", query.nextPageCommand())
	}
	if len(actions) != len(selectable) {
		fmt.Fprintln(output, "时间推进：wait 等待一天；wait complete 完成当前行动；wait next 快进到下一重要变化。")
	}
	return displayed, true
}

type terminalActionQuery struct {
	category string
	search   string
	page     int
}

func parseActionQuery(requested string) (terminalActionQuery, error) {
	query := terminalActionQuery{page: 1}
	fields := strings.Fields(strings.TrimSpace(requested))
	if len(fields) == 0 {
		return query, nil
	}
	if strings.EqualFold(fields[0], "find") || fields[0] == "搜索" {
		if len(fields) < 2 {
			return query, errors.New("用法：actions find <关键词>")
		}
		searchEnd := len(fields)
		if len(fields) >= 4 && (fields[len(fields)-2] == "page" || fields[len(fields)-2] == "页") {
			page, err := strconv.Atoi(fields[len(fields)-1])
			if err != nil || page < 1 {
				return query, errors.New("页码必须是大于零的整数")
			}
			query.page = page
			searchEnd -= 2
		}
		query.search = strings.ToLower(strings.Join(fields[1:searchEnd], " "))
		if query.search == "" {
			return query, errors.New("搜索关键词不能为空")
		}
		return query, nil
	}
	index := 0
	if fields[0] != "page" && fields[0] != "页" {
		category, valid := normalizeActionCategory(fields[0])
		if !valid || category == "" {
			return query, fmt.Errorf("未知类别 %q；可用类别：调查、交涉、准备、出行", fields[0])
		}
		query.category = category
		index++
	}
	if index < len(fields) {
		if len(fields)-index != 2 || (fields[index] != "page" && fields[index] != "页") {
			return query, errors.New("用法：actions [类别] [page <页码>]")
		}
		page, err := strconv.Atoi(fields[index+1])
		if err != nil || page < 1 {
			return query, errors.New("页码必须是大于零的整数")
		}
		query.page = page
	}
	return query, nil
}

func (q terminalActionQuery) nextPageCommand() string {
	if q.search != "" {
		return fmt.Sprintf("actions find %s page %d", q.search, q.page+1)
	}
	if q.category == "" {
		return fmt.Sprintf("actions page %d", q.page+1)
	}
	return fmt.Sprintf("actions %s page %d", q.category, q.page+1)
}

func actionMatchesSearch(action app.AvailableAction, search string) bool {
	haystack := strings.ToLower(strings.Join([]string{action.Name, action.Description, action.TargetName, action.FactClaim}, " "))
	return strings.Contains(haystack, search)
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
		fmt.Fprintln(output, "命令：look；people；talk <编号|人物ID|姓名>（进入多轮对话）；对话中直接输入回复，context 查看语境，cancel 取消生成，retry 重试，await 等待完成，leave 离开；actions [调查|交涉|准备|出行] [page 页码]；actions find <关键词>；do <行动编号>；map [all]；go <地点>；journal；wait；wait complete；wait next；saves；save [槽位]；load <槽位>；autosave [on|off]；quit。")
		return
	}
	fmt.Fprintln(output, "命令：look；people；talk <人物编号或姓名>（进入多轮对话）；对话中直接输入回复，context 查看语境，cancel 取消生成，retry 重试，await 等待完成，leave 离开；actions [调查|交涉|准备|出行] [page 页码]；actions find <关键词>；do <行动编号>；map [all]；go <地点>；journal；wait；wait complete；wait next；saves；save [槽位]；load <槽位>；autosave [on|off]；quit。")
}

func fail(err error) {
	fmt.Fprintln(os.Stderr, "play:", err)
	os.Exit(1)
}

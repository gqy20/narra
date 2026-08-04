// Command play runs the player-facing interactive terminal client.
package main

import (
	"bufio"
	"context"
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

	"narra/internal/ai"
	"narra/internal/aiconfig"
	"narra/internal/app"
	"narra/internal/scenario"
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
		session, err = app.NewSession(bundle, app.DefaultPlayer(bundle, *playerName))
	}
	if err != nil {
		fail(err)
	}
	aiRuntime, dialogue, worldDirector, err := buildPlayAIRuntime(aiConfig)
	if err != nil {
		fail(err)
	}
	game := &terminalGame{
		session: session, saves: store, autosave: *autosave,
		dialogue: dialogue, ai: aiRuntime,
	}
	game.setWorldDirector(worldDirector)
	renderAIStatus(os.Stdout, game)
	if err := runGame(os.Stdin, os.Stdout, game, dialogue, *debug); err != nil {
		fail(err)
	}
}

func runGame(input io.Reader, output io.Writer, game *terminalGame, dialogue *ai.Service, debug bool) error {
	if game.dialogue == nil {
		game.dialogue = dialogue
	}
	session := game.session
	commands := scanTerminalCommands(input)
	view := session.View()
	headerTitle := view.Presentation.WorldTitle
	if headerTitle == "" {
		headerTitle = view.Title
	}
	fmt.Fprintf(output, "%s · %s\n", view.Presentation.Brand, headerTitle)
	fmt.Fprintln(output, "输入 help 查看命令；输入 actions 查看当前选择。")
	if view.Day == 0 && (len(view.Presentation.Prologue.Beats) > 0 || view.Presentation.Intro != "") {
		fmt.Fprintln(output, "\n【序章】")
		if len(view.Presentation.Prologue.Beats) > 0 {
			for index, beat := range view.Presentation.Prologue.Beats {
				if index > 0 {
					fmt.Fprintln(output)
				}
				fmt.Fprintln(output, beat.Text)
			}
		} else {
			fmt.Fprintln(output, view.Presentation.Intro)
		}
		if view.Presentation.Objective != "" {
			fmt.Fprintln(output, "\n目标："+view.Presentation.Objective)
		}
	}
	if game.saves != nil {
		if game.autosave {
			fmt.Fprintf(output, "自动存档已开启：每次成功行动后写入 %s 槽。\n", autosaveSlot)
		} else {
			fmt.Fprintln(output, "自动存档已关闭；可输入 autosave on 开启。")
		}
	}
	actionMenuCurrent := false
	var displayedActions []app.AvailableAction
	var conversation *terminalDialogueSession
	var pendingDialogue *terminalDialogueRequest
	var retryDialogue *terminalDialogueAttempt
	var pendingAction *terminalActionRequest
	var retryAction string
	var queuedCommands []terminalCommand
	var nextDialogueRequestID uint64
	var nextActionRequestID uint64
	inputPaused := false
	renderView(output, view, debug)

	for {
		if view.Resolved || view.Ended {
			return nil
		}

		if pendingAction != nil {
			commandSource := commands
			if inputPaused {
				commandSource = nil
			}
			select {
			case completed := <-pendingAction.result:
				request := pendingAction
				stopTerminalAction(request)
				pendingAction = nil
				inputPaused = false
				if completed.requestID != request.id {
					fmt.Fprintln(output, "已忽略过期的行动结果。")
					continue
				}
				if completed.err != nil {
					view = game.session.View()
					retryAction = request.actionID
					if errors.Is(completed.err, context.Canceled) {
						fmt.Fprintln(output, "行动已取消，整项行动的变更已回滚；输入 retry 可重新结算。")
					} else {
						fmt.Fprintf(output, "行动结算失败：%v\n", completed.err)
						fmt.Fprintln(output, "会话仍然保留；输入 retry 重试，或选择其他行动。")
					}
					queuedCommands = nil
					continue
				}
				var err error
				view, err = finishTerminalAction(output, game, completed, debug)
				if err != nil {
					return err
				}
				retryAction = ""
				actionMenuCurrent = false
				displayedActions = nil
				conversation = nil
				retryDialogue = nil
				continue
			case <-pendingAction.ticker.C:
				fmt.Fprintf(output, "  已等待 %d 秒，世界行动仍在结算……\n", int(time.Since(pendingAction.started).Seconds()))
				continue
			case command, ok := <-commandSource:
				if !ok {
					commands = nil
					inputPaused = true
					continue
				}
				if command.err != nil {
					stopTerminalAction(pendingAction)
					return command.err
				}
				switch command.line {
				case "cancel":
					pendingAction.cancel()
					inputPaused = true
					fmt.Fprintln(output, "正在取消世界行动并等待事务回滚。")
				case "await":
					inputPaused = true
					fmt.Fprintf(output, "等待行动请求 %d 完成。\n", pendingAction.id)
				case "retry":
					fmt.Fprintln(output, "当前行动仍在结算；请先 cancel。")
				case "q", "quit", "exit":
					queuedCommands = append(queuedCommands, command)
					fmt.Fprintln(output, "世界行动结算完成后退出；如需回滚，请先输入 cancel。")
				default:
					queuedCommands = append(queuedCommands, command)
					fmt.Fprintln(output, "世界行动仍在结算；这条输入将在完成后处理。输入 cancel 可取消并清空排队输入。")
				}
				continue
			}
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
			brand := strings.TrimSpace(view.Presentation.Brand)
			if brand == "" {
				brand = "游戏"
			}
			fmt.Fprintf(output, "\n%s[%s·第%d天]> ", brand, view.Location.Name, view.Day)
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
				pendingDialogue = beginDialogueRequest(output, game.session, game.dialogue, *attempt, nextDialogueRequestID)
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
		case line == "ai" || strings.HasPrefix(line, "ai "):
			runAICommand(output, game, commandArgument(line))
			continue
		case line == "director" || line == "director all":
			renderDirectorAudit(output, game.session.DirectorDecisions(), debug, line == "director all")
			continue
		case line == "talk" || strings.HasPrefix(line, "talk "):
			var attempt *terminalDialogueAttempt
			conversation, attempt = prepareDialogueStart(output, game, game.dialogue, view, commandArgument(line), debug)
			if attempt != nil {
				nextDialogueRequestID++
				pendingDialogue = beginDialogueRequest(output, game.session, game.dialogue, *attempt, nextDialogueRequestID)
			}
			continue
		case line == "retry":
			if retryAction != "" && conversation == nil {
				nextActionRequestID++
				fmt.Fprintln(output, "正在重新结算上次世界行动。")
				var err error
				pendingAction, view, err = dispatchTerminalAction(output, game, retryAction, nextActionRequestID, debug)
				if err != nil {
					return err
				}
				if pendingAction == nil {
					retryAction = ""
				}
				continue
			}
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
			pendingDialogue = beginDialogueRequest(output, game.session, game.dialogue, *retryDialogue, nextDialogueRequestID)
			continue
		case line == "cancel":
			fmt.Fprintln(output, "当前没有正在生成的模型请求。")
			continue
		case line == "await":
			fmt.Fprintln(output, "当前没有需要等待的模型请求。")
			continue
		case line == "actions" || strings.HasPrefix(line, "actions "):
			var valid bool
			displayedActions, valid = renderActionsCategoryWithLabels(output, view.AvailableActions, commandArgument(line), debug, playerViewResourceLabels(view))
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
			nextActionRequestID++
			pendingAction, view, err = dispatchTerminalAction(output, game, actionID, nextActionRequestID, debug)
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
			nextActionRequestID++
			pendingAction, view, err = dispatchTerminalAction(output, game, actionID, nextActionRequestID, debug)
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
			retryAction = ""
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
			nextActionRequestID++
			pendingAction, view, err = dispatchTerminalAction(output, game, actionID, nextActionRequestID, debug)
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
	case "q", "quit", "exit", "help", "?", "look", "people", "talk", "actions", "map", "journal", "wait", "go", "saves", "autosave", "load", "save", "do", "context", "leave", "cancel", "retry", "await", "ai", "director":
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
	fmt.Fprintf(output, "快进：第 %d 天 → 下一次重要变化。\n", view.Day)
	if waitAction.Timing != "" {
		fmt.Fprintln(output, "  - "+waitAction.Timing)
	}
	for _, warning := range waitAction.Warnings {
		fmt.Fprintln(output, "  - 风险："+warning)
	}
	for _, progress := range view.RouteProgresses {
		if progress.Window != "" {
			fmt.Fprintf(output, "  - %s路线窗口：%s\n", progress.Label, progress.Window)
		}
	}
	fmt.Fprintln(output, "确认：wait next confirm；只等一天：wait。")
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
	if game.worldDirector != nil {
		loaded.SetWorldDirector(game.worldDirector)
	}
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
	if view.Resolved || view.Ended {
		fmt.Fprintf(output, "局势结束：%s\n", view.Outcome)
		if view.Ending != nil && len(view.Ending.Coda) > 0 {
			fmt.Fprintln(output, presentationText(view, "ending_coda_heading", "你的余波")+"：")
			for _, consequence := range view.Ending.Coda {
				fmt.Fprintf(output, "  - %s\n", consequence)
			}
		}
		if debug && view.Ending != nil {
			additionalConsequences := endingConsequencesExcept(view.Ending.PlayerConsequences, view.Ending.Coda)
			if len(additionalConsequences) > 0 {
				fmt.Fprintln(output, "本局余波：")
				for _, consequence := range additionalConsequences {
					fmt.Fprintf(output, "  - %s\n", consequence)
				}
			}
			renderInfluences(output, view.Ending.Influence, true, "你的介入")
			if len(view.Ending.Review) > 0 {
				fmt.Fprintln(output, "结算依据：")
				for _, review := range view.Ending.Review {
					fmt.Fprintf(output, "  - %s\n", review)
				}
			}
			fmt.Fprintf(output, "调试统计：决策=%d，行动=%d，推进=%d，自动略过=%d 天，结果日=%d。\n",
				view.Metrics.DecisionInputs, view.Metrics.ActiveActions, view.Metrics.WaitActions, view.Metrics.AutoAdvancedDays, view.Metrics.CoreResultDay)
		}
		return
	}
	if view.LastTurn != nil {
		fmt.Fprintf(output, "上回合：%s [%s]\n", view.LastTurn.Action, statusLabel(view.LastTurn.Status))
		if debug && view.LastTurn.DaysAdvanced > 1 {
			fmt.Fprintf(output, "  - 推进了 %d 天，其中 %d 天没有需要处理的变化。\n", view.LastTurn.DaysAdvanced, view.LastTurn.QuietDays)
		}
		for index, message := range view.LastTurn.Messages {
			if index >= 2 {
				break
			}
			fmt.Fprintf(output, "  - %s\n", message)
		}
		if debug {
			renderInfluences(output, view.LastTurn.Influence, true, "情报回响")
		}
	}

	resourceKeys := make([]string, 0, len(view.Player.Resources))
	for key := range view.Player.Resources {
		resourceKeys = append(resourceKeys, key)
	}
	sort.Strings(resourceKeys)
	resources := make([]string, 0, len(resourceKeys))
	resourceLabels := playerViewResourceLabels(view)
	for _, key := range resourceKeys {
		if view.Player.Resources[key] == 0 {
			continue
		}
		resources = append(resources, fmt.Sprintf("%s=%d", resourceLabel(resourceLabels, key), view.Player.Resources[key]))
	}
	playerSummary := view.Player.Name
	if view.Player.Injury > 0 {
		playerSummary += fmt.Sprintf("｜伤势 %d", view.Player.Injury)
	}
	if len(resources) > 0 {
		playerSummary += "｜" + strings.Join(resources, "  ")
	}
	fmt.Fprintln(output, playerSummary)

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
		fmt.Fprintf(output, "%s：%d 条（输入 journal 查看）\n", presentationText(view, "term_clues", "线索"), len(view.KnownFacts))
	}
	if len(view.KnownActors) > 0 {
		names := make([]string, 0, len(view.KnownActors))
		for _, actor := range view.KnownActors {
			names = append(names, actor.Name)
		}
		fmt.Fprintf(output, "同地人物：%s\n", strings.Join(names, "、"))
	}
	if len(view.Guidance) > 0 {
		fmt.Fprintf(output, "眼下：%s\n", view.Guidance[0])
	}
	if view.Travel != nil {
		fmt.Fprintf(output, "行程：%s · %d 天。\n", view.Travel.Destination, view.Travel.TravelDays)
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

func endingConsequencesExcept(all, visible []string) []string {
	hidden := make(map[string]bool, len(visible))
	for _, text := range visible {
		hidden[text] = true
	}
	result := make([]string, 0, len(all))
	for _, text := range all {
		if !hidden[text] {
			result = append(result, text)
		}
	}
	return result
}

func renderActions(output io.Writer, actions []app.AvailableAction, debug bool) {
	renderActionsCategory(output, actions, "", debug)
}

func renderActionsCategory(output io.Writer, actions []app.AvailableAction, requested string, debug bool) ([]app.AvailableAction, bool) {
	return renderActionsCategoryWithLabels(output, actions, requested, debug, nil)
}

func renderActionsCategoryWithLabels(output io.Writer, actions []app.AvailableAction, requested string, debug bool, resourceLabels map[string]string) ([]app.AvailableAction, bool) {
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
				parts = append(parts, fmt.Sprintf("%s %d", resourceLabel(resourceLabels, key), amount))
			}
			sort.Strings(parts)
			cost = "；花费 " + strings.Join(parts, "、")
		}
		id := ""
		if debug {
			id = " [" + action.ID + "]"
		}
		duration := fmt.Sprintf("%d 天", action.Duration)
		fmt.Fprintf(output, "  %d. %s%s（%s%s）\n", index+1, action.Name, id, duration, cost)
		decisionNotes := make([]string, 0, 3)
		if len(action.ExpectedOutcomes) > 0 {
			decisionNotes = append(decisionNotes, "预期："+strings.Join(action.ExpectedOutcomes, "、"))
		}
		if action.Timing != "" {
			decisionNotes = append(decisionNotes, "时机："+action.Timing)
		}
		if len(action.Warnings) > 0 {
			decisionNotes = append(decisionNotes, "注意："+strings.Join(action.Warnings, "、"))
		}
		if len(decisionNotes) > 0 {
			fmt.Fprintf(output, "     %s\n", strings.Join(decisionNotes, "；"))
		}
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
	case "verify", "opportunity":
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

func playerViewResourceLabels(view app.PlayerView) map[string]string {
	labels := make(map[string]string, len(view.Presentation.Resources))
	for _, resource := range view.Presentation.Resources {
		labels[resource.ID] = resource.Label
	}
	return labels
}

func resourceLabel(labels map[string]string, key string) string {
	if label := labels[key]; label != "" {
		return label
	}
	return key
}

func presentationText(view app.PlayerView, key, fallback string) string {
	if text := strings.TrimSpace(view.Presentation.UI[key]); text != "" {
		return text
	}
	return fallback
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
		fmt.Fprintln(output, "命令：look；people；talk <编号|人物ID|姓名>（进入多轮对话）；对话中直接输入回复，context 查看语境，cancel 取消生成，retry 重试，await 等待完成，leave 离开；actions [调查|交涉|准备|出行] [page 页码]；actions find <关键词>；do <行动编号>；map [all]；go <地点>；journal；director [all]；ai status/config；wait；wait complete；wait next；saves；save [槽位]；load <槽位>；autosave [on|off]；quit。")
		return
	}
	fmt.Fprintln(output, "命令：look；people；talk <人物编号或姓名>（进入多轮对话）；对话中直接输入回复，context 查看语境，cancel 取消生成，retry 重试，await 等待完成，leave 离开；actions [调查|交涉|准备|出行] [page 页码]；actions find <关键词>；do <行动编号>；map [all]；go <地点>；journal；director [all]；ai status/config；wait；wait complete；wait next；saves；save [槽位]；load <槽位>；autosave [on|off]；quit。")
}

func fail(err error) {
	fmt.Fprintln(os.Stderr, "play:", err)
	os.Exit(1)
}

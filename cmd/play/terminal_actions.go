package main

import (
	"context"
	"fmt"
	"io"
	"time"

	"narra/internal/app"
)

type terminalActionResult struct {
	requestID uint64
	view      app.PlayerView
	err       error
}

type terminalActionRequest struct {
	id       uint64
	actionID string
	result   chan terminalActionResult
	ticker   *time.Ticker
	started  time.Time
	cancel   context.CancelFunc
}

func beginTerminalAction(output io.Writer, game *terminalGame, actionID string, requestID uint64) *terminalActionRequest {
	ctx, cancel := context.WithCancel(context.Background())
	result := make(chan terminalActionResult, 1)
	fmt.Fprintln(output, "行动正在结算；输入 cancel 可取消并回滚整项行动，await 可等待完成。")
	go func() {
		view, err := game.session.ExecuteContext(ctx, actionID)
		result <- terminalActionResult{requestID: requestID, view: view, err: err}
	}()
	return &terminalActionRequest{
		id: requestID, actionID: actionID, result: result,
		ticker: time.NewTicker(5 * time.Second), started: time.Now(), cancel: cancel,
	}
}

func dispatchTerminalAction(output io.Writer, game *terminalGame, actionID string, requestID uint64, debug bool) (*terminalActionRequest, app.PlayerView, error) {
	if game.worldDirector == nil {
		view, err := executeTerminalAction(output, game, actionID, debug)
		return nil, view, err
	}
	return beginTerminalAction(output, game, actionID, requestID), game.session.View(), nil
}

func stopTerminalAction(request *terminalActionRequest) {
	if request == nil {
		return
	}
	request.cancel()
	request.ticker.Stop()
}

func finishTerminalAction(output io.Writer, game *terminalGame, result terminalActionResult, debug bool) (app.PlayerView, error) {
	if game.autosave && game.saves != nil {
		if err := game.saves.save(autosaveSlot, game.session); err != nil {
			return app.PlayerView{}, fmt.Errorf("autosave: %w", err)
		}
	}
	renderView(output, result.view, debug)
	if !result.view.Resolved && !result.view.Ended {
		renderActionRefresh(output, result.view.AvailableActions)
	}
	return result.view, nil
}

package app

import (
	"fmt"

	"fantu/internal/domain"
)

func (s *Session) routeProgress(state *domain.WorldState) *RouteProgress {
	playerID := state.Player.ID
	location := s.visibleLocation("L02").Name
	if state.ActorFlag(playerID, "qinglan_intel_term_trust") {
		progress := &RouteProgress{ID: "trust", Label: "信任担保", Location: location, PersonalReturn: "宗门记功，或把关系兑现为入谷物资与支援"}
		switch {
		case state.ActorFlag(playerID, "qinglan_trust_operation_joined"):
			progress.Status, progress.NextStep, progress.Complete = "已转为亲自行动", "带着宗门物资准备入谷", true
		case state.ActorFlag(playerID, "qinglan_trust_commissioned"):
			progress.Status, progress.NextStep, progress.Complete = "已结算报酬", "观察沈砚秋能否兑现后续记功", true
		case state.ActorFlag(playerID, "qinglan_trust_betrayed"):
			progress.Status, progress.NextStep, progress.Complete = "已经背约", "赵鹤鸣已取得计划，无法恢复担保", true
		case state.ActorFlag(playerID, "qinglan_trust_rewarded"):
			progress.Status, progress.NextStep, progress.Complete = "承诺已经兑现", "沈砚秋已为你记功", true
		case state.ActorFlag(playerID, "qinglan_trust_vouched"):
			progress.DeadlineDay, progress.Window = 16, "第14—16日"
			if state.Day < 14 {
				progress.Status, progress.NextStep = "等待兑现", "第14日起向沈砚秋选择：领取行动物资，或领取情报报酬"
			} else if state.Day <= 16 {
				progress.Status, progress.NextStep, progress.Urgent = "可以兑现", "返回青岚门驻地，决定担保带来的个人收益", true
			} else {
				progress.Status, progress.NextStep, progress.Complete = "兑现窗口已错过", "担保仍会影响沈砚秋，但你没有领取中期回报", true
			}
		default:
			progress.DeadlineDay, progress.Window = 12, "第10—12日"
			if state.Day < 10 {
				progress.Status, progress.NextStep = "等待审核", "第10日起回到青岚门驻地，回应赵鹤鸣的公开质疑"
			} else if state.Day <= 12 {
				progress.Status, progress.NextStep, progress.Urgent = "必须回应", "在驻地公开担保，或把计划转交赵鹤鸣", true
			} else {
				progress.Status, progress.NextStep, progress.Complete = "审核窗口已错过", "本次担保没有形成宗门记功", true
			}
		}
		return progress
	}
	if state.ActorFlag(playerID, "qinglan_intel_term_antidote") {
		progress := &RouteProgress{ID: "antidote", Label: "解瘴丹交易", Location: location, PersonalReturn: "保留独行资格，并可选择踩点或转售变现"}
		switch {
		case state.ActorFlag(playerID, "qinglan_antidote_scouted"):
			progress.Status, progress.NextStep, progress.Complete = "独行踩点完成", "综合准备已经提高，按时进入内谷", true
		case state.ActorFlag(playerID, "qinglan_antidote_liquidated"):
			progress.Status, progress.NextStep, progress.Complete = "入谷资格已变现", "你已卖出丹药与路线，不再参与核心争夺", true
		case state.ActorFlag(playerID, "qinglan_antidote_lent"):
			progress.Status, progress.NextStep, progress.Complete = "已经借丹援队", "独行路线关闭，支援与关系收益已到账", true
		case state.ActorFlag(playerID, "qinglan_antidote_kept"):
			progress.DeadlineDay, progress.Window = 16, "第13—16日"
			if state.Day < 13 {
				progress.Status, progress.NextStep = "保留独行资格", "第13日起决定：提前踩点提高准备，或转售丹药与路线"
			} else if state.Day <= 16 {
				progress.Status, progress.NextStep, progress.Urgent = "可以兑现", "在青岚门驻地选择独行收益出口", true
			} else {
				progress.Status, progress.NextStep, progress.Complete = "兑现窗口已错过", "仍可持丹入谷，但没有取得踩点或交易收益", true
			}
		default:
			progress.DeadlineDay, progress.Window = 12, "第8—12日"
			if state.Day < 8 {
				progress.Status, progress.NextStep = "等待药物缺口", "第8日起回应苏晚照的借丹请求"
			} else if state.Day <= 12 {
				progress.Status, progress.NextStep, progress.Urgent = "必须回应", "在驻地决定借丹援队，或确认独行", true
			} else {
				progress.Status, progress.NextStep, progress.Complete = "回应窗口已错过", "丹药仍在手中，但苏晚照的请求已经失效", true
			}
		}
		return progress
	}
	if state.ActorFlag(playerID, "qinglan_intel_term_escort") {
		progress := &RouteProgress{ID: "escort", Label: "青岚同行", Location: location, PersonalReturn: "随队丹药、支援，以及先锋或后勤分工收益"}
		switch {
		case state.ActorFlag(playerID, "qinglan_escort_vanguard"):
			progress.Status, progress.NextStep, progress.Complete = "先锋分工已确定", "带领人手按时进入内谷", true
		case state.ActorFlag(playerID, "qinglan_escort_quartermaster"):
			progress.Status, progress.NextStep, progress.Complete = "后勤分工已确定", "个人报酬已到账，可继续决定是否入谷", true
		case state.ActorFlag(playerID, "qinglan_escort_fulfilled"):
			progress.DeadlineDay, progress.Window = 18, "第17—18日"
			if state.Day <= 18 {
				progress.Status, progress.NextStep, progress.Urgent = "等待分工", "出发前选择担任先锋，或负责后勤领取报酬", true
			} else {
				progress.Status, progress.NextStep, progress.Complete = "分工窗口已错过", "你仍保留随队丹药与基础支援", true
			}
		case state.ActorFlag(playerID, "qinglan_escort_refused"):
			progress.Status, progress.NextStep, progress.Complete = "已经退出同行", "保持散修身份，自行寻找入谷条件", true
		case state.ActorFlag(playerID, "qinglan_escort_approved"):
			progress.DeadlineDay, progress.Window = 16, "仅第16日"
			if state.Day < 16 {
				progress.Status, progress.NextStep = "审核通过", "第16日回到青岚门驻地兑现同行承诺"
			} else if state.Day == 16 {
				progress.Status, progress.NextStep, progress.Urgent = "立即集结", "今天在驻地领取随队丹药与人手", true
			} else {
				progress.Status, progress.NextStep, progress.Complete = "集结已经错过", "同行承诺失效", true
			}
		default:
			progress.DeadlineDay, progress.Window = 13, "第10—13日"
			if state.Day < 10 {
				progress.Status, progress.NextStep = "等待宗门审核", "第10日起回驻地确认同行身份"
			} else if state.Day <= 13 {
				progress.Status, progress.NextStep, progress.Urgent = "必须审核", "接受审核保留同行，或退出名单", true
			} else {
				progress.Status, progress.NextStep, progress.Complete = "审核窗口已错过", "第16日不再获得集结资格", true
			}
		}
		return progress
	}
	return nil
}

func routeProgressWarning(progress *RouteProgress, day int) string {
	if progress == nil || progress.Complete || !progress.Urgent {
		return ""
	}
	deadline := ""
	if progress.DeadlineDay > 0 {
		deadline = fmt.Sprintf("；最迟第 %d 日处理", progress.DeadlineDay)
	}
	return fmt.Sprintf("路线提醒 · %s：%s%s。", progress.Label, progress.NextStep, deadline)
}

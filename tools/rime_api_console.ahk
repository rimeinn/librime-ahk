/*
 * Copyright (c) 2023 - 2026 Xuesong Peng <pengxuesong.cn@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * Original C++ code rime_api_console.cc
 */
#Requires AutoHotkey v2.0
#Include "..\rime_api.ahk"

AppendLog(gui, message) {
    local log := gui["Log"]
    log.Value := log.Value ? log.Value . "`r`n" . message : message
    ControlSend("^{End}", log)
}

StatusText(status) {
    local out := status.schema_name ? status.schema_name : "未选择方案"
    local flags := []
    if status.is_disabled {
        flags.Push("已禁用")
    }
    if status.is_composing {
        flags.Push("输入中")
    }
    if status.is_ascii_mode {
        flags.Push("ASCII")
    }
    if status.is_full_shape {
        flags.Push("全角")
    }
    if status.is_simplified {
        flags.Push("简体")
    }
    return flags.Length ? out . " · " . Join(flags, " · ") : out
}

Join(items, separator := "") {
    local result := ""
    for index, item in items {
        result .= (index = 1 ? "" : separator) . item
    }
    return result
}

UpdateStatus(state) {
    if (status := state.api.get_status(state.session_id)) {
        state.gui["Status"].Text := StatusText(status)
        state.api.free_status(status)
    }
}

UpdateComposition(state, context) {
    local composition := context.composition
    if composition.length > 0 {
        state.gui["Composition"].Text := composition.preedit
    } else {
        state.gui["Composition"].Text := "（未输入）"
    }
}

UpdateCandidates(state, context) {
    local list, menu, candidates, candidate
    list := state.gui["Candidates"]
    list.Delete()
    menu := context.menu
    if menu.num_candidates = 0 {
        state.gui["Page"].Text := "无候选"
        state.gui["PrevPage"].Enabled := false
        state.gui["NextPage"].Enabled := false
        return
    }

    candidates := menu.candidates
    Loop menu.num_candidates {
        candidate := candidates[A_Index]
        list.Add(, menu.page_no * menu.page_size + A_Index, candidate.text, candidate.comment)
    }
    state.gui["Page"].Text := "第 " . (menu.page_no + 1) . " 页" . (menu.is_last_page ? "" : " · 还有下一页")
    state.gui["PrevPage"].Enabled := menu.page_no > 0
    state.gui["NextPage"].Enabled := !menu.is_last_page
}

RefreshView(state, logSession := true) {
    if !state.ready {
        return
    }
    if logSession {
        if commit := state.api.get_commit(state.session_id) {
            AppendLog(state.gui, "提交: " . commit.text)
            state.api.free_commit(commit)
        }
    }
    UpdateStatus(state)
    if (context := state.api.get_context(state.session_id)) {
        UpdateComposition(state, context)
        UpdateCandidates(state, context)
        state.api.free_context(context)
    }
}

LoadSchemas(state) {
    local dropdown, items, current
    dropdown := state.gui["Schema"]
    dropdown.Delete()
    state.schema_ids := Map()
    if !(schemas := state.api.get_schema_list()) {
        return
    }

    items := []
    Loop schemas.size {
        schema := schemas.list[A_Index]
        label := schema.name . " (" . schema.schema_id . ")"
        items.Push(label)
        state.schema_ids[label] := schema.schema_id
    }
    dropdown.Add(items)
    current := state.api.get_current_schema(state.session_id, 100)
    for index, label in items {
        if state.schema_ids[label] = current {
            dropdown.Choose(index)
            break
        }
    }
    state.api.free_schema_list(schemas)
}

SelectSchema(state, ctrl, *) {
    if !state.ready || !ctrl.Value {
        return
    }
    schema_id := state.schema_ids[ctrl.Text]
    if state.api.select_schema(state.session_id, schema_id) {
        AppendLog(state.gui, "已切换方案: " . schema_id)
        RefreshView(state, false)
    } else {
        MsgBox("无法切换方案: " . schema_id, "Rime")
    }
}

RefreshSchemas(state, *) {
    LoadSchemas(state)
    RefreshView(state, false)
}

ChangePage(state, backward, *) {
    if state.ready && state.api.change_page(state.session_id, backward) {
        RefreshView(state, false)
    }
}

SetOption(state, option, ctrl, *) {
    if !state.ready {
        return
    }
    value := ctrl.Value = 1
    state.api.set_option(state.session_id, option, value)
    AppendLog(state.gui, option . " = " . (value ? "on" : "off"))
    RefreshView(state, false)
}

SetAdvancedOption(state, *) {
    option := Trim(state.gui["AdvancedOption"].Value)
    if !option {
        return
    }
    value := state.gui["AdvancedValue"].Value = 1
    state.api.set_option(state.session_id, option, value)
    AppendLog(state.gui, option . " = " . (value ? "on" : "off"))
    state.gui["AdvancedOption"].Value := ""
    RefreshView(state, false)
}

SendKeySequence(state, *) {
    if !state.ready {
        return
    }
    input := state.gui["Input"].Value
    if !input {
        return
    }
    state.gui["Input"].Value := ""
    AppendLog(state.gui, "按键序列: " . input)
    if state.api.simulate_key_sequence(state.session_id, input) {
        RefreshView(state)
    } else {
        MsgBox("无法处理按键序列: " . input, "Rime")
    }
}

ToggleLog(state, ctrl, *) {
    visible := state.gui["Log"].Visible
    state.gui["Log"].Visible := !visible
    ctrl.Text := visible ? "显示日志" : "隐藏日志"
    state.gui.Show("AutoSize")
}

OnMessage(context_object, session_id, message_type, message_value) {
    msg := StrGet(message_type, "UTF-8") . ": " . StrGet(message_value, "UTF-8")
    TrayTip(msg, "Session: " . session_id)
}

ExitRimeConsole(state, *) {
    if state.session_id {
        state.api.destroy_session(state.session_id)
    }
    state.api.finalize()
}

main() {
    rime := RimeApi()
    traits := RimeTraits()
    traits.app_name := "rime.ahk_console"
    traits.shared_data_dir := "rime"
    traits.user_data_dir := "rime"

    Main := Gui(, "AHK Rime GUI")
    Main.MarginX := 14
    Main.MarginY := 12
    Main.SetFont("S10", "Microsoft YaHei UI")
    Main.OnEvent("Close", (*) => ExitApp())

    Main.AddText("xm ym", "方案")
    schema := Main.AddDropDownList("x+8 yp-4 w260 vSchema")
    refreshButton := Main.AddButton("x+6 yp w72", "刷新")
    status := Main.AddText("xm y+10 w430 vStatus", "初始化中…")

    Main.AddGroupBox("xm y+10 w520 h98", "输入")
    composition := Main.AddText("x26 yp+28 w496 h24 vComposition cBlue", "（未输入）")
    input := Main.AddEdit("x26 y+10 w400 h28 vInput -Multi")
    send := Main.AddButton("x+8 yp w84 Default", "发送")

    Main.AddGroupBox("xm y+12 w520 h184", "候选词")
    candidates := Main.AddListView("x26 yp+28 w496 h120 vCandidates -Multi", ["序号", "候选", "注释"])
    candidates.ModifyCol(1, 55)
    candidates.ModifyCol(2, 200)
    candidates.ModifyCol(3, 220)
    page := Main.AddText("x26 y+8 w230 vPage", "无候选")
    prevPage := Main.AddButton("x+50 yp-4 w92 vPrevPage Disabled", "上一页")
    nextPage := Main.AddButton("x+8 yp w92 vNextPage Disabled", "下一页")

    Main.AddGroupBox("xm y+12 w520 h100", "常用选项")
    ascii := Main.AddCheckBox("x26 yp+28 vAscii", "ASCII 模式")
    fullShape := Main.AddCheckBox("x+24 yp vFullShape", "全角模式")
    simplified := Main.AddCheckBox("x+24 yp vSimplified", "简体模式")
    Main.AddText("xm+8 y+16", "高级 option")
    advancedOption := Main.AddEdit("x+8 yp-4 w180 vAdvancedOption -Multi")
    advancedValue := Main.AddCheckBox("x+8 yp+2 vAdvancedValue", "开启")
    advancedSet := Main.AddButton("x+12 yp-4 w72", "应用")

    logToggleButton := Main.AddButton("xm y+24 w92", "隐藏日志")
    log := Main.AddEdit("xm y+8 w520 r8 ReadOnly VScroll vLog")

    state := {api: rime, gui: Main, session_id: 0, ready: false, schema_ids: Map()}
    schema.OnEvent("Change", SelectSchema.Bind(state))
    refreshButton.OnEvent("Click", RefreshSchemas.Bind(state))
    send.OnEvent("Click", SendKeySequence.Bind(state))
    prevPage.OnEvent("Click", ChangePage.Bind(state, true))
    nextPage.OnEvent("Click", ChangePage.Bind(state, false))
    ascii.OnEvent("Click", SetOption.Bind(state, "ascii_mode"))
    fullShape.OnEvent("Click", SetOption.Bind(state, "full_shape"))
    simplified.OnEvent("Click", SetOption.Bind(state, "simplification"))
    advancedSet.OnEvent("Click", SetAdvancedOption.Bind(state))
    logToggleButton.OnEvent("Click", ToggleLog.Bind(state))

    Main.Show("AutoSize")
    AppendLog(Main, "初始化中…")
    rime.setup(traits)
    rime.set_notification_handler(OnMessage, 0)
    rime.initialize(0)
    if rime.start_maintenance(true) {
        rime.join_maintenance_thread()
    }

    state.session_id := rime.create_session()
    if !state.session_id {
        MsgBox("无法创建 Rime 会话。", "Rime")
        ExitApp(1)
    }
    state.ready := true
    Main.Title := "AHK Rime GUI (Session " . state.session_id . ")"
    OnExit(ExitRimeConsole.Bind(state))
    LoadSchemas(state)
    RefreshView(state, false)
    AppendLog(Main, "已就绪。回车或点击“发送”可发送按键序列。")
    input.Focus()
}

main()

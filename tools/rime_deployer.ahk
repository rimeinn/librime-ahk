/*
 * Copyright (c) 2023, 2025 Xuesong Peng <pengxuesong.cn@gmail.com>
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
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Original C++ code rime_api_console.cc
 *
 * Copyright RIME Developers
 * Distributed under the BSD License
 *
 * 2012-07-07 GONG Chen <chen.sst@gmail.com>
 *
 */
#Requires AutoHotkey v2.0
#Include "..\rime_api.ahk"

; rime := RimeApi()
; traits := RimeTraits()
; traits.shared_data_dir := "rime"
; traits.user_data_dir := "rime"
; traits.modules := [ "deployer" ]

; rime.deployer_initialize(traits)
; rime.run_task("workspace_update")

; setup_deployer() {
;     ; 
; }

on_message(context_object, session_id, message_type, message_value) {
    msg := StrGet(message_type, "UTF-8") . ": " . StrGet(message_value, "UTF-8")
    TrayTip(msg, "Session: " . session_id)
}

select_dir(tag, GuiCtrlObj, Info) {
    GuiObj := GuiCtrlObj.Gui
    starting_dir := GuiObj[tag].Value
    starting_dir := "*" . (DirExist(starting_dir) ? starting_dir : A_WorkingDir)
    dir := DirSelect(starting_dir, 3)
    if dir
        GuiObj[tag].Value := dir
}

confirm(tab, GuiCtrlObj, Info) {
    GuiObj := GuiCtrlObj.Gui
    switch tab.Value {
        case 1:
            traits := RimeTraits()
            user_dir := GuiObj["UserDataDirInput"].Value
            traits.user_data_dir := user_dir ? user_dir : A_WorkingDir
            shared_dir := GuiObj["SharedDataDirInput"].Value
            traits.shared_data_dir := shared_dir ? shared_dir : A_WorkingDir
            staging_dir := GuiObj["StagingDirInput"].Value
            traits.staging_dir := staging_dir ? staging_dir : traits.user_data_dir . "\build"
            traits.prebuilt_data_dir := traits.shared_data_dir . "\build"
            traits.modules := [ "deployer" ]
            rime := RimeApi()
            rime.setup(traits)
            rime.deployer_initialize(0)
            if rime.run_task("workspace_update")
                MsgBox("部署成功")
            else
                MsgBox("部署失败")
        case 2:
        default:
            ; 
    }
}

main() {
    weasel_shared_data_dir := RegRead("HKEY_LOCAL_MACHINE\Software\Rime\Weasel", "WeaselRoot", "")
    if weasel_shared_data_dir
        weasel_shared_data_dir := Format("{}\data", weasel_shared_data_dir)
    else
        weasel_shared_data_dir := Format("{}\rime", A_WorkingDir)

    weasel_user_data_dir := RegRead("HKEY_CURRENT_USER\Software\Rime\Weasel", "RimeUserDir", "")
    if not weasel_user_data_dir
        weasel_user_data_dir := Format("{}\rime", A_WorkingDir)

    Main := Gui()
    Main.MarginX := 10
    Main.MarginY := 10
    Main.SetFont("S12", "Microsoft YaHei UI")
    Main.Title := "AHK Rime Deployer"
    tabs := Main.AddTab3(, [ "部署", "添加方案", "编译", "激活方案" ])
    Main.AddGroupBox("w320 r1 section", "用户数据目录")
    Main.AddEdit("vUserDataDirInput -Multi w240 xs+10 ys+26 r1", weasel_user_data_dir).GetPos(, , , &height)
    Main.AddButton("hp yp", "选择").OnEvent("Click", select_dir.Bind("UserDataDirInput"))
    Main.AddGroupBox("w320 r1 section xs y+m", "共享数据目录")
    Main.AddEdit("vSharedDataDirInput -Multi w240 xs+10 ys+26 r1", weasel_shared_data_dir)
    Main.AddButton("hp yp", "选择").OnEvent("Click", select_dir.Bind("SharedDataDirInput"))
    Main.AddGroupBox("w320 r1 section xs y+m", "构建目录，留空默认为用户目录内的 build")
    Main.AddEdit("vStagingDirInput -Multi w240 xs+10 ys+26 r1")
    Main.AddButton("hp yp", "选择").OnEvent("Click", select_dir.Bind("StagingDirInput"))
    tabs.UseTab(2)
    Main.AddGroupBox("w320 r1 section", "用户数据目录")
    Main.AddEdit("vUserDataDirInput2 -Multi w240 xs+10 ys+26 r1", weasel_user_data_dir).GetPos(, , , &height)
    Main.AddButton("hp yp", "选择").OnEvent("Click", select_dir.Bind("UserDataDirInput2"))
    Main.AddText("xs" , "每行一个方案 ID")
    Main.AddEdit("vAddSchemaInput w320 r3")
    tabs.UseTab()
    Main.AddButton("Default vDftBtn w80 xp+250 y+m h" . height, "确定").OnEvent("Click", confirm.Bind(tabs))
    Main.Show("AutoSize")
}

main()

; rimeDll := DllCall("LoadLibrary", "Str", "rime.dll", "Ptr")
; api := DllCall("rime\rime_get_api", "CDecl")
; DllCall("rime\?SetupDeployer@rime@@YAXPAUrime_traits_t@@@Z", "Ptr", traits.struct_ptr(), "CDecl")

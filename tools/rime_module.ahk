/*
 * Copyright (c) 2026 Xuesong Peng <pengxuesong.cn@gmail.com>
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
 */
#Requires AutoHotkey v2.0
#include ..\rime_api.ahk

class AhkRimeApi extends RimeApiStruct {
    __New(ptr := 0) {
        local real_size
        local copy_size

        super.__New(AhkRimeApi.struct_size, 0)

        if ptr {
            real_size := A_IntSize + NumGet(
                ptr,
                AhkRimeApi.data_size_offset,
                "Int"
            )
            if real_size <= A_IntSize {
                throw RimeError("Invalid AHK module API data size.")
            }

            copy_size := Min(real_size, AhkRimeApi.struct_size)
            this.copy(ptr, , , copy_size)
        } else {
            this.num_put(
                "Int",
                AhkRimeApi.struct_size - A_IntSize,
                AhkRimeApi.data_size_offset
            )
        }
    }

    static data_size_offset := 0
    static hello_offset := AhkRimeApi.data_size_offset + A_IntSize + A_IntPaddingSize
    static struct_size := AhkRimeApi.hello_offset + A_PtrSize

    Hello() {
        local hello_callback

        if !this.has_member("hello") {
            return false
        }

        hello_callback := this.fp(AhkRimeApi.hello_offset)
        if !hello_callback {
            return false
        }

        DllCall(hello_callback, "CDecl")
        return true
    }
}

class AhkRimeModule {
    __New(rime, name) {
        this.api := AhkRimeApi()
        this.module := RimeModule()
        this.module.module_name := name

        this.initialize_handler := this.OnInitialize.Bind(this)
        this.finalize_handler := this.OnFinalize.Bind(this)
        this.get_api_handler := this.OnGetApi.Bind(this)
        this.hello_handler := this.Hello.Bind(this)

        this.initialize_callback := CallbackCreate(this.initialize_handler, "C", 0)
        this.finalize_callback := CallbackCreate(this.finalize_handler, "C", 0)
        this.get_api_callback := CallbackCreate(this.get_api_handler, "C", 0)
        this.hello_callback := CallbackCreate(this.hello_handler, "C", 0)

        NumPut("Ptr", this.initialize_callback, this.module, RimeModule.initialize_offset)
        NumPut("Ptr", this.finalize_callback, this.module, RimeModule.finalize_offset)
        NumPut("Ptr", this.get_api_callback, this.module, RimeModule.get_api_offset)
        NumPut("Ptr", this.hello_callback, this.api, AhkRimeApi.hello_offset)

        if !rime.register_module(this.module) {
            throw RimeError("Failed to register AHK module.")
        }
    }
    __Delete() {
        this.Dispose()
    }

    Hello() {
        MsgBox("Hello from AHK Rime module!")
    }

    OnInitialize() {
        FileAppend("AHK Rime module initialized`n", "*")
    }

    OnFinalize() {
        FileAppend("AHK Rime module finalized`n", "*")
    }

    OnGetApi() {
        return this.api.Ptr
    }

    Dispose() {
        CallbackFree(this.initialize_callback)
        CallbackFree(this.finalize_callback)
        CallbackFree(this.get_api_callback)
        CallbackFree(this.hello_callback)

        this.initialize_callback := 0
        this.finalize_callback := 0
        this.get_api_callback := 0
        this.hello_callback := 0
    }
}

rime := RimeApi()

_ := AhkRimeModule(rime, "ahk_module")

traits := RimeTraits()
traits.app_name := "rime.ahk_module"
traits.shared_data_dir := "rime"
traits.user_data_dir := "rime"
traits.modules := ["default", "ahk_module"]

rime.setup(traits)
rime.initialize(traits)

module := rime.find_module("ahk_module")
if !module {
    throw RimeError("Cannot find AHK module")
}

if !(api_ptr := module.get_api()) {
    throw RimeError("AHK module has no custom API")
}

ahk_api := AhkRimeApi(api_ptr)
ahk_api.Hello()

rime.finalize()

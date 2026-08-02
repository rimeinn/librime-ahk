/*
 * Copyright (c) 2024 Xuesong Peng <pengxuesong.cn@gmail.com>
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

#Include ..\rime_api.ahk

/**
 * # Port of `rime::Switches`
 * 
 * ## Usage sample
 * 
 * ```AutoHotkey
 * ShowSwitches(rime_api, session_id) {
 *     if not status := rime_api.get_status(session_id) {
 *         MsgBox("Failed to get rime status!")
 *         return
 *     }
 *     local schema_id := status.schema_id
 *     rime_api.free_status(status)
 * 
 *     if not config := rime_api.schema_open(schema_id) {
 *         MsgBox("Failed to get current schema's config!")
 *         return
 *     }
 * 
 *     local switches := RimeSwitches(rime_api, config)
 *     local switch_size := switches.size
 *     local msg := "Total " . switch_size . " switches"
 *     Loop switch_size {
 *         local option := switches.by_index(A_Index - 1)
 *         if not option.found
 *             continue
 *         msg := msg . "`r`n " . A_Index . ". " . option.option_name
 *         if option.type = RimeSwitches.kRadioGroup {
 *             local radio_size := option.size
 *             Loop radio_size {
 *                 if A_Index = 1
 *                     continue ; already added to msg
 *                 option := switches.cycle(option)
 *                 if not option.found or option.type = RimeSwitches.kToggleOption
 *                     break
 *                 msg := msg . ", " . option.option_name
 *             }
 *         }
 *     }
 *     rime_api.config_close(config)
 *     MsgBox(msg)
 * }
 * ```
 */
class RimeSwitches extends Object {
    /**
     * 
     * @param rime `RimeApi` released by caller
     * @param config `RimeConfig` released by caller
     */
    __New(api, config) {
        this.api := api
        this.config := config
    }

    static kToggleOption {
        get => 0
    }
    static kRadioGroup {
        get => 1
    }

    class SwitchOption extends Object {
        __New(caller := 0, path := "", type := RimeSwitches.kToggleOption, name := "", switch_index := 0, option_index := 0) {
            if caller {
                this.path := path
                this.type := type
                this.option_name := name
                if path and caller.api.config_test_get_int(caller.config, path . "/reset", &reset)
                    this.reset_value := reset
                this.switch_index := switch_index
                this.option_index := option_index

                if !this.found
                    this.size := 0
                else if this.type = RimeSwitches.kToggleOption
                    this.size := 1
                else
                    this.size := caller.api.config_list_size(caller.config, path . "/options")
            }
        }

        path := ""
        type := RimeSwitches.kToggleOption
        option_name := ""
        ; reset state value on initialize. -1 if unspecified.
        reset_value := -1
        ; index of the switch configuration.
        switch_index := 0
        ; the index of the option in the radio group.
        option_index := 0

        found {
            get => !!this.path
        }
    } ; SwitchOption

    static kContinue {
        get => 0
    }
    static kFound {
        get => 1
    }

    size {
        get => this.api.config_list_size(this.config, "switches")
    }

    find_option(callback) {
        if not iter := this.api.config_begin_list(this.config, "switches")
            return RimeSwitches.SwitchOption()
        while this.api.config_next(iter) {
            ; the method `IsMap`, `IsList`, etc. are not callable by AHK
            ; try to get map iter and success means "IsMap"
            if not opt_iter := this.api.config_begin_map(this.config, iter.path)
                continue
            this.api.config_end(opt_iter)
            local option := this._find_option_from_config_iter(iter, A_Index - 1, callback)
            if option.found {
                this.api.config_end(iter)
                return option
            }
        }
        this.api.config_end(iter)
        return RimeSwitches.SwitchOption()
    }

    option_by_name(option_name) {
        return this.find_option((option*) => (option.option_name == option_name ? RimeSwitches.kFound : RimeSwitches.kContinue))
    }

    ; Returns the switch option defined at switch_index.
    ; If the switch is a radio group, return the first option in the group.
    by_index(switch_index) {
        local size := this.api.config_list_size(this.config, "switches")
        if size <= switch_index
            return RimeSwitches.SwitchOption()
        if not iter := this.api.config_begin_list(this.config, "switches")
            return RimeSwitches.SwitchOption()
        ; `GetAt` and `GetValueAt` are not callable by AHK
        ; loop to get the value
        while this.api.config_next(iter) {
            if A_Index - 1 != switch_index
                continue
            local option := this._find_option_from_config_iter(iter, switch_index, (*) => RimeSwitches.kFound)
            if option.found {
                this.api.config_end(iter)
                return option
            }
        }
        this.api.config_end(iter)
        return RimeSwitches.SwitchOption()
    }

    ; current - `RimeSwitches.SwitchOption`
    cycle(current) {
        if not size := this.api.config_list_size(this.config, current.path . "/options")
            return RimeSwitches.SwitchOption()
        local next_option_index := Mod(current.option_index + 1 , size)
        if next_option_index = current.option_index
            return RimeSwitches.SwitchOption()
        if not iter := this.api.config_begin_list(this.config, current.path . "/options")
            return RimeSwitches.SwitchOption()
        ; `GetAt` and `GetValueAt` are not callable by AHK
        ; loop to get the value
        while this.api.config_next(iter) {
            if A_Index - 1 != next_option_index
                continue
            if not name := this.api.config_get_string(this.config, iter.path)
                continue
            local option := RimeSwitches.SwitchOption(
                this, current.path, current.type,
                name, current.switch_index, next_option_index
            )
            this.api.config_end(iter)
            return option
        }
        this.api.config_end(iter)
        return RimeSwitches.SwitchOption()
    }

    reset(current) {
        local default_state := (current.reset_value >= 0) ? current.reset_value : 0
        if not size := this.api.config_list_size(this.config, current.path . "/options")
            return RimeSwitches.SwitchOption()
        if default_state >= size or default_state = current.option_index
            return RimeSwitches.SwitchOption()
        if not iter := this.api.config_begin_list(this.config, current.path . "/options")
            return RimeSwitches.SwitchOption()
        while this.api.config_next(iter) {
            if A_Index - 1 != default_state
                continue
            if not name := this.api.config_get_string(this.config, iter.path)
                continue
            local option := RimeSwitches.SwitchOption(
                this, current.path, current.type,
                name, current.switch_index, default_state
            )
            this.api.config_end(iter)
            return option
        }
        this.api.config_end(iter)
        return RimeSwitches.SwitchOption()
    }

    find_radio_group_option(path, callback) {
        if not iter := this.api.config_begin_list(this.config, path . "/options")
            return RimeSwitches.SwitchOption()
        while this.api.config_next(iter) {
            if not name := this.api.config_get_string(this.config, iter.path)
                continue
            local option := RimeSwitches.SwitchOption(
                this, path, RimeSwitches.kRadioGroup, name,
                0, ; switch index unknown
                A_Index - 1
            )
            if callback(option) = RimeSwitches.kFound {
                this.api.config_end(iter)
                return option
            }
        }
        this.api.config_end(iter)
        return RimeSwitches.SwitchOption()
    }

    /**
     * Similar to API's `get_state_label_abbreviated`,
     * but can be also used for non current schemas
     * @param option_name `Str`, e.g. "ascii_mode"
     * @param state `True` or `False`
     * @param abbreviated `True` or `False`
     * @returns {String} the label
     */
    get_state_label(option_name, state, abbreviated) {
        local option := this.option_by_name(option_name)
        if not option.found
            return ""
        if option.type = RimeSwitches.kToggleOption
            return RimeSwitches._get_state_label(this.api, this.config, option.path, state, abbreviated)
        if option.type = RimeSwitches.kRadioGroup {
            ; if the query is a deselected option among the radio group, do not
            ; display its state label; only show the selected option.
            return state ? RimeSwitches._get_state_label(
                this.api, this.config, option.path,
                option.option_index, abbreviated
            ) : ""
        }
        return ""
    }

    _find_option_from_config_iter(iter, switch_index, callback) {
        if name := this.api.config_get_string(this.config, iter.path . "/name") {
            local option := RimeSwitches.SwitchOption(
                this, iter.path, RimeSwitches.kToggleOption,
                name, switch_index
            )
            if callback(option) = RimeSwitches.kFound
                return option
        } else if list_iter := this.api.config_begin_list(this.config, iter.path . "/options") {
            while this.api.config_next(list_iter) {
                if not name := this.api.config_get_string(this.config, list_iter.path)
                    continue
                local option := RimeSwitches.SwitchOption(
                    this, iter.path, RimeSwitches.kRadioGroup,
                    name, switch_index, A_Index - 1
                )
                if callback(option) = RimeSwitches.kFound {
                    this.api.config_end(list_iter)
                    return option
                }
            }
            this.api.config_end(list_iter)
        }
        return RimeSwitches.SwitchOption()
    }

    static _get_state_label(rime_api, config, path, state_index, abbreviated) {
        local state_size
        local abbrev_path
        local abbrev_size
        local label_path
        local iter

        if !rime_api || !config || !path || state_index < 0 {
            return ""
        }

        state_size := rime_api.config_list_size(
            config,
            path . "/states"
        )
        if state_size <= state_index {
            return ""
        }

        label_path := path . "/states"

        if abbreviated {
            abbrev_path := path . "/abbrev"
            abbrev_size := rime_api.config_list_size(
                config,
                abbrev_path
            )
            if abbrev_size > state_index {
                label_path := abbrev_path
            }
        }

        if !(iter := rime_api.config_begin_list(
            config,
            label_path
        )) {
            return ""
        }

        try {
            while rime_api.config_next(iter) {
                if A_Index - 1 == state_index {
                    return rime_api.config_get_string(
                        config,
                        iter.path
                    )
                }
            }
            return ""
        } finally {
            rime_api.config_end(iter)
        }
    }
} ; RimeSwitches

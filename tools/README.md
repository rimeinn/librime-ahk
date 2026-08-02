# Rime tools

Examples to demonstrate the usages. Require `rime.dll` to run.

## Rime API Console

Ported from [rime_api_console.cc](https://github.com/rime/librime/blob/master/tools/rime_api_console.cc).

```powershell
& 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' rime_api_console.ahk
```

## AHK Rime Module

Demonstrate the definitions of a custom Rime module and the associated API struct.

```powershell
& 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' rime_module.ahk | Write-Output
```

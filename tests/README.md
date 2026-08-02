# Tests

The test suite uses the first-party runner in `test_runner.ahk`. It has no
runtime dependencies outside AutoHotkey v2 and the library under test.

Run it from the repository root:

```powershell
& 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' tests\rime_test_main.ahk | Write-Output
```

The process exits with code `0` when all tests pass and `1` when any test
fails. JUnit output is written to `tests\junit.xml`.

Test methods are named `Test_*`. A test class may define `Begin()` and
`End()` methods; a fresh class instance is created for every test method.

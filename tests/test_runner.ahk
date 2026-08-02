#Requires AutoHotkey v2.0

class TestRunner {
    static Assert(condition, message := "Assertion failed") {
        if !condition
            throw Error(message, -1)
    }

    static Equal(expected, actual, message := "") {
        if expected != actual {
            if !message
                message := Format("Expected '{}', got '{}'", expected, actual)
            throw Error(message, -1)
        }
    }

    static Run(classes*) {
        results := []
        for cls in classes {
            className := cls.Prototype.__Class
            for methodName in cls.Prototype.OwnProps() {
                if SubStr(methodName, 1, 5) != "Test_"
                    continue

                result := {
                    className: className,
                    methodName: methodName,
                    passed: false,
                    error: ""
                }
                instance := cls()
                try {
                    if instance.HasMethod("Begin")
                        instance.Begin()
                    instance.%methodName%()
                    result.passed := true
                } catch Error as err {
                    result.error := err.Message
                    if err.File != ""
                        result.error .= Format(" ({}:{})", err.File, err.Line)
                } finally {
                    if instance.HasMethod("End") {
                        try instance.End()
                        catch Error as err {
                            if result.passed {
                                result.passed := false
                                result.error := "End(): " err.Message
                            }
                        }
                    }
                }
                results.Push(result)
            }
        }
        return results
    }

    static WriteJUnit(results, path) {
        failures := 0
        for result in results
            failures += !result.passed

        xml := '<?xml version="1.0" encoding="UTF-8"?>`r`n'
        xml .= Format('<testsuites failures="{}" tests="{}">`r`n', failures, results.Length)
        xml .= Format('`t<testsuite failures="{}" tests="{}" name="AHK">`r`n', failures, results.Length)
        for result in results {
            xml .= Format('`t`t<testcase name="{}" classname="{}"', this.XmlEscape(result.methodName), this.XmlEscape(result.className))
            if result.passed {
                xml .= '/>`r`n'
            } else {
                xml .= Format('>`r`n`t`t`t<failure message="{}" />`r`n`t`t</testcase>`r`n', this.XmlEscape(result.error))
            }
        }
        xml .= '`t</testsuite>`r`n</testsuites>`r`n'
        if FileExist(path)
            FileDelete(path)
        FileAppend(xml, path, "UTF-8")
        return failures
    }

    static Print(results, path := "*") {
        for result in results {
            label := result.passed ? "PASS" : "FAIL"
            line := Format("{} {}::{}", label, result.className, result.methodName)
            if !result.passed
                line .= " - " result.error
            FileAppend(line "`n", path)
        }
        FileAppend(Format("{} tests, {} failed`n", results.Length, this.FailureCount(results)), path)
    }

    static FailureCount(results) {
        failures := 0
        for result in results
            failures += !result.passed
        return failures
    }

    static XmlEscape(value) {
        value := StrReplace(value, "&", "&amp;")
        value := StrReplace(value, "<", "&lt;")
        value := StrReplace(value, ">", "&gt;")
        value := StrReplace(value, '"', "&quot;")
        return StrReplace(value, "'", "&apos;")
    }
}

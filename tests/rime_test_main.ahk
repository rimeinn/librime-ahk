#Include test_runner.ahk

#Include ..\rime_api.ahk
#Include ..\rime_levers_api.ahk

class RimeStringTests {
    Begin() {
        this.str1 := RimeString("Hello, World!")
        this.str2 := RimeString("你好，世界！")
        this.str3 := RimeString("🐇🐰")
        this.str4 := RimeString("床前明月光，疑是地上霜。`r`n举头望明月，低头思故乡。")
        this.str5 := RimeString("قد ومن فرنسا الإمتعاض, استراليا، وبريطانيا ما كما. حين بـ سبتمبر الأولى لمحاكم, يكن وحتّى منتصف ما. لمّ ويعزى وهولندا، قد, و دخول شعار نهاية نفس. عرض وإقامة للإتحاد عل, مع قام وبعد وتتحمّل, جُل خيار البرية المتّبعة إذ. لكون إستعمل لم هذا, تم به، أوزار والقرى.")
    }

    Test_Size() {
        TestRunner.Assert(this.str1.Size == 14)
        TestRunner.Assert(this.str2.Size == 19)
        TestRunner.Assert(this.str3.Size == 9)
        TestRunner.Assert(this.str4.Size == 75)
        TestRunner.Assert(this.str5.Size == 462)
    }

    Test_ToString() {
        TestRunner.Assert(String(this.str1) == "Hello, World!")
        TestRunner.Assert(String(this.str2) == "你好，世界！")
        TestRunner.Assert(String(this.str3) == "🐇🐰")
        TestRunner.Assert(String(this.str4) == "床前明月光，疑是地上霜。`r`n举头望明月，低头思故乡。")
        TestRunner.Assert(String(this.str5) == "قد ومن فرنسا الإمتعاض, استراليا، وبريطانيا ما كما. حين بـ سبتمبر الأولى لمحاكم, يكن وحتّى منتصف ما. لمّ ويعزى وهولندا، قد, و دخول شعار نهاية نفس. عرض وإقامة للإتحاد عل, مع قام وبعد وتتحمّل, جُل خيار البرية المتّبعة إذ. لكون إستعمل لم هذا, تم به، أوزار والقرى.")
    }

    End() {
        this.DeleteProp("str1")
        this.DeleteProp("str2")
        this.DeleteProp("str3")
    }
}

class RimeNullTerminatedStringArrayTests {
    Begin() {
        local values := ["Hello", "你好", "🐇🐰"]

        this.str_arr := RimeNullTerminatedStringArray(values)
        TestRunner.Assert(values.Length == 3)
    }

    Test_Basic() {
        TestRunner.Assert(this.str_arr.Length == 3)
        TestRunner.Assert(this.str_arr.Size == 4 * A_PtrSize + 22)
        TestRunner.Assert(
            NumGet(this.str_arr, 3 * A_PtrSize, "Ptr") == 0
        )
    }

    Test_Empty() {
        local str_arr := RimeNullTerminatedStringArray()

        TestRunner.Assert(str_arr.Length == 0)
        TestRunner.Assert(str_arr.Size == A_PtrSize)
        TestRunner.Assert(NumGet(str_arr, 0, "Ptr") == 0)
    }
}

class RimeTraitsTests {
    Begin() {
        this.traits := RimeTraits()
    }

    Test_Basic() {
        TestRunner.Assert(this.traits.data_size == 10 * A_PtrSize + A_IntSize + 2 * A_IntPaddingSize)
    }

    Test_ModulesAreNullTerminated() {
        this.traits.modules := ["default", "autohotkey"]
        TestRunner.Assert(NumGet(this.traits.__modules, 2 * A_PtrSize, "Ptr") == 0)
        TestRunner.Assert(this.traits.__modules.Length == 2) ; act like a native AutoHotkey array
        TestRunner.Assert(this.traits.modules.Length == 2)
        TestRunner.Assert(this.traits.modules[1] == "default")
        TestRunner.Assert(this.traits.modules[2] == "autohotkey")
    }

    End() {
        this.DeleteProp("traits")
    }
}

Class RimeApiTests {
    Begin() {
        api := RimeApi()
        traits := RimeTraits()
        traits.shared_data_dir := traits.user_data_dir := traits.prebuilt_data_dir := traits.staging_dir := "."
        traits.app_name := "rime.test"
        api.setup(traits)
        api.initialize(0)
        this.api := api
        this.levers := RimeLeversApi(api)
        this.na_msg := "API {} not available"
    }

    ; Rime has multi-threading components, which
    ; are beyond AutoHotkey's capability to handle.
    ; Therefore all tests must be done within one function.
    Test_All() {
        api := this.api

        TestRunner.Assert(api.data_size == 98 * A_PtrSize + A_IntPaddingSize)

        fn := "create_session"
        TestRunner.Assert(api.api_available(fn), Format(this.na_msg, fn))
        local test_session := api.create_session()
        TestRunner.Assert(0 !== test_session)

        fn := "get_context"
        TestRunner.Assert(api.api_available(fn), Format(this.na_msg, fn))
        ctx := api.get_context(test_session)
        TestRunner.Assert(0 !== ctx)
        TestRunner.Assert(0 == ctx.menu.num_candidates)

        fn := "get_status"
        TestRunner.Assert(api.api_available(fn), Format(this.na_msg, fn))
        status := api.get_status(test_session)
        TestRunner.Assert(0 !== status)
        TestRunner.Assert(!status.is_composing)

        fn := "destroy_session"
        TestRunner.Assert(api.api_available(fn), Format(this.na_msg, fn))
        TestRunner.Assert(api.destroy_session(test_session))


        levers := this.levers

        TestRunner.Assert(levers.data_size == 32 * A_PtrSize + A_IntPaddingSize)

        fn := "custom_settings_init"
        TestRunner.Assert(levers.api_available(fn), Format(this.na_msg, fn))
        custom_settings := levers.custom_settings_init("levers_test", "rime_test")
        TestRunner.Assert(!!custom_settings)

        fn := "customize_bool"
        TestRunner.Assert(levers.api_available(fn), Format(this.na_msg, fn))
        TestRunner.Assert(levers.customize_bool(custom_settings, "test_key", true))

        fn := "custom_settings_destroy"
        TestRunner.Assert(levers.api_available(fn), Format(this.na_msg, fn))
        levers.custom_settings_destroy(custom_settings)
    }

    Test_ApiCopiesLastFunctionPointer() {
        local ptr := DllCall("rime\rime_get_api", "CDecl Ptr")

        TestRunner.Assert(this.api.fp(RimeApi.change_page_offset) == NumGet(ptr, RimeApi.change_page_offset, "Ptr"))
    }

    End() {
        this.api.finalize()
        this.DeleteProp("api")
        this.DeleteProp("levers")
        this.DeleteProp("na_msg")
    }
}

results := TestRunner.Run(RimeStringTests, RimeNullTerminatedStringArrayTests, RimeTraitsTests, RimeApiTests)
failures := TestRunner.WriteJUnit(results, A_ScriptDir "\junit.xml")
TestRunner.Print(results, "*")
ExitApp(failures ? 1 : 0)

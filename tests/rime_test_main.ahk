#Include Yunit\Yunit.ahk
#Include Yunit\Stdout.ahk
#Include Yunit\OutputDebug.ahk
#Include Yunit\JUnit.ahk
#Include Yunit\Window.ahk

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
        Yunit.Assert(this.str1.Size == 14)
        Yunit.Assert(this.str2.Size == 19)
        Yunit.Assert(this.str3.Size == 9)
        Yunit.Assert(this.str4.Size == 75)
        Yunit.Assert(this.str5.Size == 462)
    }

    Test_ToString() {
        Yunit.Assert(String(this.str1) == "Hello, World!")
        Yunit.Assert(String(this.str2) == "你好，世界！")
        Yunit.Assert(String(this.str3) == "🐇🐰")
        Yunit.Assert(String(this.str4) == "床前明月光，疑是地上霜。`r`n举头望明月，低头思故乡。")
        Yunit.Assert(String(this.str5) == "قد ومن فرنسا الإمتعاض, استراليا، وبريطانيا ما كما. حين بـ سبتمبر الأولى لمحاكم, يكن وحتّى منتصف ما. لمّ ويعزى وهولندا، قد, و دخول شعار نهاية نفس. عرض وإقامة للإتحاد عل, مع قام وبعد وتتحمّل, جُل خيار البرية المتّبعة إذ. لكون إستعمل لم هذا, تم به، أوزار والقرى.")
    }

    End() {
        this.DeleteProp("str1")
        this.DeleteProp("str2")
        this.DeleteProp("str3")
    }
}

class RimeStringArrayTests {
    Begin() {
        arr := ["Hello", "你好", "🐇🐰"]
        this.str_arr := RimeStringArray(arr)
    }

    Test_Basic() {
        Yunit.Assert(this.str_arr.Size == (3 * A_PtrSize + 22))
        Yunit.Assert(this.str_arr[0] !== 0)
    }

    Test_StringAt() {
        Yunit.Assert(this.str_arr[1] == "Hello")
        Yunit.Assert(this.str_arr[2] == "你好")
        Yunit.Assert(this.str_arr[3] == "🐇🐰")
    }

    End() {
        this.DeleteProp("str_arr")
    }
}

class RimeTraitsTests {
    Begin() {
        this.traits := RimeTraits()
    }

    Test_Basic() {
        Yunit.Assert(this.traits.data_size == 10 * A_PtrSize + A_IntSize + 2 * A_IntPaddingSize)
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
    AllTests() {
        api := this.api

        Yunit.Assert(api.data_size == 98 * A_PtrSize + A_IntPaddingSize)

        fn := "create_session"
        Yunit.Assert(api.api_available(fn), Format(this.na_msg, fn))
        local test_session := api.create_session()
        Yunit.Assert(0 !== test_session)

        fn := "get_context"
        Yunit.Assert(api.api_available(fn), Format(this.na_msg, fn))
        ctx := api.get_context(test_session)
        Yunit.Assert(0 !== ctx)
        Yunit.Assert(0 == ctx.menu.num_candidates)

        fn := "get_status"
        Yunit.Assert(api.api_available(fn), Format(this.na_msg, fn))
        status := api.get_status(test_session)
        Yunit.Assert(0 !== status)
        Yunit.Assert(!status.is_composing)

        fn := "destroy_session"
        Yunit.Assert(api.api_available(fn), Format(this.na_msg, fn))
        Yunit.Assert(api.destroy_session(test_session))


        levers := this.levers

        Yunit.Assert(levers.data_size == 32 * A_PtrSize + A_IntPaddingSize)

        fn := "custom_settings_init"
        Yunit.Assert(levers.api_available(fn), Format(this.na_msg, fn))
        custom_settings := levers.custom_settings_init("levers_test", "rime_test")
        Yunit.Assert(!!custom_settings)

        fn := "customize_bool"
        Yunit.Assert(levers.api_available(fn), Format(this.na_msg, fn))
        Yunit.Assert(levers.customize_bool(custom_settings, "test_key", true))

        fn := "custom_settings_destroy"
        Yunit.Assert(levers.api_available(fn), Format(this.na_msg, fn))
        levers.custom_settings_destroy(custom_settings)
    }

    End() {
        this.api.finalize()
        this.DeleteProp("api")
        this.DeleteProp("levers")
        this.DeleteProp("na_msg")
    }
}

if A_Args.Length {
    Yunit.Use(YunitJUnit).Test(RimeStringTests, RimeStringArrayTests, RimeTraitsTests, RimeApiTests)
} else {
    Yunit.Use(YunitStdOut, YunitOutputDebug, YunitJUnit, YunitWindow).Test(RimeStringTests, RimeStringArrayTests, RimeTraitsTests, RimeApiTests)
}

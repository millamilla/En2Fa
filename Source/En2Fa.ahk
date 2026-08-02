#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn

; ===============================================================
; Config Management
; ===============================================================
class Config {
    static FileName := "En2Fa.ini"
    
    static ReadHotkey() {
        if FileExist(this.FileName) {
            hotkeyValue := IniRead(this.FileName, "Settings", "Hotkey", "F8")
            return hotkeyValue
        }
        return "F8"
    }
    
    static WriteHotkey(hotkeyValue) {
        IniWrite(hotkeyValue, this.FileName, "Settings", "Hotkey")
    }
    
    static ReadHotkey2() {
        if FileExist(this.FileName) {
            hotkeyValue := IniRead(this.FileName, "Settings", "Hotkey2", "F9")
            return hotkeyValue
        }
        return "F9"
    }
    
    static WriteHotkey2(hotkeyValue) {
        IniWrite(hotkeyValue, this.FileName, "Settings", "Hotkey2")
    }
    
    static ReadAutoSwitch() {
        if FileExist(this.FileName) {
            value := IniRead(this.FileName, "Settings", "AutoSwitch", "1")
            return (value = "1")
        }
        return true
    }
    
    static WriteAutoSwitch(value) {
        IniWrite(value ? "1" : "0", this.FileName, "Settings", "AutoSwitch")
    }
    
    static ReadAutoSwitch2() {
        if FileExist(this.FileName) {
            value := IniRead(this.FileName, "Settings", "AutoSwitch2", "0")
            return (value = "1")
        }
        return false
    }
    
    static WriteAutoSwitch2(value) {
        IniWrite(value ? "1" : "0", this.FileName, "Settings", "AutoSwitch2")
    }
    
    static IsFirstRun() {
        if FileExist(this.FileName) {
            firstRun := IniRead(this.FileName, "Settings", "FirstRun", "1")
            return (firstRun = "1")
        }
        return true
    }
    
    static SetFirstRunComplete() {
        IniWrite("0", this.FileName, "Settings", "FirstRun")
    }
}

; ===============================================================
; Global Variables
; ===============================================================
CurrentHotkey := Config.ReadHotkey()
CurrentHotkey2 := Config.ReadHotkey2()
AutoSwitchLanguage := Config.ReadAutoSwitch()
AutoSwitchLanguage2 := Config.ReadAutoSwitch2()
HotkeysEnabled := true

; تنظیم آیکون‌ها با پشتیبانی از FileInstall برای exe
if (A_IsCompiled) {
    ; وقتی فایل کامپایل شده است، آیکون‌ها را از داخل exe استخراج کن
    FileInstall("Enable.ico", A_Temp "\Enable.ico", 1)
    FileInstall("Disable.ico", A_Temp "\Disable.ico", 1)
    TrayIconActive := A_Temp "\Enable.ico"
    TrayIconDisabled := A_Temp "\Disable.ico"
} else {
    ; وقتی فایل ahk است، از مسیر کنونی استفاده کن
    TrayIconActive := A_ScriptDir "\Enable.ico"
    TrayIconDisabled := A_ScriptDir "\Disable.ico"
}

; بررسی وجود آیکون‌ها و استفاده از آیکون پیش‌فرض در صورت عدم وجود
if (!FileExist(TrayIconActive)) {
    TrayIconActive := "Shell32.dll"
    TrayIconActiveIndex := 44
}
if (!FileExist(TrayIconDisabled)) {
    TrayIconDisabled := "Shell32.dll"
    TrayIconDisabledIndex := 110
}

; ===============================================================
; Startup Management Functions
; ===============================================================
GetStartupRegistryPath() {
    return "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
}

GetStartupValueName() {
    return "PersianTranslator"
}

IsStartupEnabled() {
    try {
        value := RegRead(GetStartupRegistryPath(), GetStartupValueName())
        return (value != "")
    }
    return false
}

EnableStartup() {
    try {
        exePath := A_ScriptFullPath
        if (A_IsCompiled) {
            try RegWrite(exePath, "REG_SZ", GetStartupRegistryPath(), GetStartupValueName())
            catch {
                return false
            }
            return true
        } else {
            try RegWrite('"' A_AhkPath '" "' exePath '"', "REG_SZ", GetStartupRegistryPath(), GetStartupValueName())
            catch {
                return false
            }
            return true
        }
    }
    return false
}

DisableStartup() {
    try {
        try RegDelete(GetStartupRegistryPath(), GetStartupValueName())
        catch {
            return false
        }
        return true
    }
    return false
}

ToggleStartup(*) {
    if (IsStartupEnabled()) {
        if (DisableStartup()) {
            ShowMessage("❌ اجرای خودکار غیرفعال شد", 1500)
            UpdateStartupMenuItem()
        }
    } else {
        if (EnableStartup()) {
            ShowMessage("✅ اجرای خودکار فعال شد", 1500)
            UpdateStartupMenuItem()
        }
    }
}

UpdateStartupMenuItem() {
    try {
        A_TrayMenu.Delete("اجرای خودکار با ویندوز")
    }
    
    A_TrayMenu.Insert("1&", "اجرای خودکار با ویندوز", ToggleStartup)
    
    if (IsStartupEnabled()) {
        A_TrayMenu.Check("اجرای خودکار با ویندوز")
    } else {
        A_TrayMenu.Uncheck("اجرای خودکار با ویندوز")
    }
}

; ===============================================================
; ساخت منوی System Tray و مدیریت کلیک‌ها
; ===============================================================

; رویداد کلیک چپ روی آیکون tray
OnMessage(0x404, HandleTrayClick)

HandleTrayClick(wParam, lParam, msg, hwnd) {
    try {
        if (lParam = 0x201)  ; کلیک چپ
            ToggleHotkeys()
    }
}

ToggleHotkeys() {
    global HotkeysEnabled, TrayIconActive, TrayIconDisabled
    global TrayIconActiveIndex, TrayIconDisabledIndex

    if (HotkeysEnabled) {
        DisableAllHotkeys()
        HotkeysEnabled := false
        
        ; تنظیم آیکون غیرفعال
        if (FileExist(TrayIconDisabled) && !InStr(TrayIconDisabled, ".dll")) {
            try TraySetIcon(TrayIconDisabled)
            catch {
                try TraySetIcon("Shell32.dll", 110)
            }
        } else if (IsSet(TrayIconDisabledIndex)) {
            try TraySetIcon(TrayIconDisabled, TrayIconDisabledIndex)
            catch {
                try TraySetIcon("Shell32.dll", 110)
            }
        }
    } else {
        EnableAllHotkeys()
        HotkeysEnabled := true
        
        ; تنظیم آیکون فعال
        if (FileExist(TrayIconActive) && !InStr(TrayIconActive, ".dll")) {
            try TraySetIcon(TrayIconActive)
            catch {
                try TraySetIcon("Shell32.dll", 44)
            }
        } else if (IsSet(TrayIconActiveIndex)) {
            try TraySetIcon(TrayIconActive, TrayIconActiveIndex)
            catch {
                try TraySetIcon("Shell32.dll", 44)
            }
        }
    }
}


; ===============================================================
; تابع برای تنظیم آیکون دلخواه
; ===============================================================
SetCustomTrayIcon() {
    global TrayIconActive, TrayIconActiveIndex
    
    ; ابتدا سعی می‌کنیم آیکون دلخواه را تنظیم کنیم
    if (FileExist(TrayIconActive) && !InStr(TrayIconActive, ".dll")) {
        try {
            TraySetIcon(TrayIconActive)
            return true
        }
    }
    
    ; اگر آیکون پیدا نشد یا خطا داشت، از آیکون پیش‌فرض استفاده می‌کنیم
    if (IsSet(TrayIconActiveIndex)) {
        try TraySetIcon(TrayIconActive, TrayIconActiveIndex)
        catch {
            try TraySetIcon("Shell32.dll", 44)
        }
    } else {
        try TraySetIcon("Shell32.dll", 44)
    }
    return false
}

; ===============================================================
; Key Map Builder
; ===============================================================
GetKeyMap() {
    static map := BuildKeyMap()
    return map
}

BuildKeyMap() {
    m := Map()
    
    ; --- Small English to Persian ---
    m["a"] := "ش"
    m["b"] := "ذ" 
    m["c"] := "ز"
    m["d"] := "ی"
    m["e"] := "ث"
    m["f"] := "ب"
    m["g"] := "ل"
    m["h"] := "ا"
    m["i"] := "ه"
    m["j"] := "ت"
    m["k"] := "ن"
    m["l"] := "م"
    m["m"] := "ئ"
    m["n"] := "د"
    m["o"] := "خ"
    m["p"] := "ح"
    m["q"] := "ض"
    m["r"] := "ق"
    m["s"] := "س"
    m["t"] := "ف"
    m["u"] := "ع"
    m["v"] := "ر"
    m["w"] := "ص"
    m["x"] := "ط"
    m["y"] := "غ"
    m["z"] := "ظ"
    m[";"] := "ک"
    m[","] := "و"
    m["."] := "."
    m["/"] := "/"
    m["\"] := "پ"
    m["'"] := "گ"
    m["``"] := "'"
    m["]"] := "چ"
    m["["] := "ج"
    m["-"] := "-"
    m["="] := "="
    m["?"] := "؟"
    
    ; --- Capital English to Persian ---
    m["A"] := "َ"
    m["B"] := "إ"
    m["C"] := "ژ"
    m["D"] := "ِ"
    m["E"] := "ٍ"
    m["F"] := "ّ"
    m["G"] := "ۀ"
    m["H"] := "آ"
    m["I"] := "]"
    m["J"] := "ـ"
    m["K"] := "«"
    m["L"] := "»"
    m["M"] := "ء"
    m["N"] := "أ"
    m["O"] := "O"
    m["P"] := "P"
    m["Q"] := "ً"
    m["R"] := "ريال"
    m["S"] := "ُ"
    m["T"] := "،"
    m["U"] := ","
    m["V"] := "ؤ"
    m["W"] := "ٌ"
    m["X"] := "ي"
    m["Y"] := "؛"
    m["Z"] := "ة"
    
    ; --- Persian to English (Reverse Map) ---
    m["ش"] := "a"
    m["ذ"] := "b"
    m["ز"] := "c"
    m["ی"] := "d"
    m["ث"] := "e"
    m["ب"] := "f"
    m["ل"] := "g"
    m["ا"] := "h"
    m["ه"] := "i"
    m["ت"] := "j"
    m["ن"] := "k"
    m["م"] := "l"
    m["ئ"] := "m"
    m["د"] := "n"
    m["خ"] := "o"
    m["ح"] := "p"
    m["ض"] := "q"
    m["ق"] := "r"
    m["س"] := "s"
    m["ف"] := "t"
    m["ع"] := "u"
    m["ر"] := "v"
    m["ص"] := "w"
    m["ط"] := "x"
    m["غ"] := "y"
    m["ظ"] := "z"
    m["ک"] := ";"
    m["و"] := ","
    m["گ"] := "'"
    m["چ"] := "]"
    m["ج"] := "["
    m["پ"] := "\"
    m["َ"] := "A"
    m["إ"] := "B"
    m["ژ"] := "C"
    m["ِ"] := "D"
    m["ٍ"] := "E"
    m["ّ"] := "F"
    m["ۀ"] := "G"
    m["آ"] := "H"
    m["]"] := "I"
    m["ـ"] := "J"
    m["«"] := "K"
    m["»"] := "L"
    m["ء"] := "M"
    m["أ"] := "N"
    m["O"] := "O"
    m["P"] := "P"
    m["ً"] := "Q"
    m["ريال"] := "R"
    m["ُ"] := "S"
    m["،"] := "T"
    m["ٌ"] := "W"
    m["ي"] := "X"
    m["؛"] := "Y"
    m["ة"] := "Z"
    m[":"] := ":"
    m["؟"] := "?"
    
    return m
}

; ===============================================================
; Helper Functions - Optimized
; ===============================================================
GetCharScore(char) {
    if (char == "")
        return 0
    
    static neutralChars := Map(" ", 1, ".", 1, "/", 1, "-", 1, "=" , 1)
    if (neutralChars.Has(char))
        return 0
    
    code := Ord(char)
    
    if ((code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A))
        return 1
    
    if (code >= 0x600 && code <= 0x6FF)
        return -1
    
    return 0
}

GetEnglishContextChar(char) {
    static contextMap := Map(
        "[", "ج", "]", "چ", "\", "پ",
        ",", "و", ";", "ک", "'", "گ", "``", "گ"
    )
    return contextMap.Has(char) ? contextMap[char] : char
}

GetPersianContextChar(char) {
    static contextMap := Map(
        "[", "O", "]", "I", "\", "P",
        ",", "U", ";", ";", "'", "'", "``", "'"
    )
    return contextMap.Has(char) ? contextMap[char] : char
}

transformeText(text, map) {
    result := ""
    chars := StrSplit(text)
    len := chars.Length
    
    Loop len {
        i := A_Index
        char := chars[i]
        
if (InStr("[],\;'``", char)) {

    score := GetContextScore(chars, i)

    if (score > 0)
        result .= GetEnglishContextChar(char)
    else if (score < 0)
        result .= GetPersianContextChar(char)
    else {
        lang := DetectTextLanguage(text)

        if (lang = "EN")
            result .= GetEnglishContextChar(char)
        else if (lang = "FA")
            result .= GetPersianContextChar(char)
        else
            result .= char
    }
}
        else {
            result .= map.Has(char) ? map[char] : char
        }
    }
    
    return result
}

ShowMessage(msg, duration) {
    ToolTip(msg)
    SetTimer(() => ToolTip(), -duration)
}

DetectTextLanguage(text) {
    en := 0
    fa := 0

    for ch in StrSplit(text) {
        code := Ord(ch)

        if ((code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A))
            en++
        else if (code >= 0x600 && code <= 0x6FF)
            fa++
    }

    if (fa > en)
        return "FA"
    else if (en > fa)
        return "EN"
    else
        return "UNKNOWN"
}

GetContextScore(chars, index) {
    score := 0
    len := chars.Length

    Loop 3 {
        offset := A_Index

        if (index - offset >= 1)
            score += GetCharScore(chars[index - offset])

        if (index + offset <= len)
            score += GetCharScore(chars[index + offset])
    }

    return score
}

; ===============================================================
; Hotkey Functions
; ===============================================================
transformeHotkey() {
    static isRunning := false
    if (isRunning)
        return
    isRunning := true

    static lastCall := 0
    currentTime := A_TickCount
    
    if (currentTime - lastCall < 800) {
        isRunning := false
        return
    }
    lastCall := currentTime

    try {
        activeClass := ""
        try {
            activeClass := WinGetClass("A")
        } catch {
            activeClass := ""
        }

        ; شناسایی برنامه‌ها
        isWord := InStr(activeClass, "OpusApp") || InStr(activeClass, "Word")
        isPPT := InStr(activeClass, "PowerPoint") || InStr(activeClass, "PP12FrameClass")
        isOutlook := InStr(activeClass, "Outlook") || InStr(activeClass, "rctrl_renwnd32")
        isOneNote := InStr(activeClass, "OneNote") || InStr(activeClass, "Framework::CFrame")
        isAutoCorrectApp := isWord || isPPT || isOutlook || isOneNote
        
        isChrome := InStr(activeClass, "Chrome_WidgetWin_1")
        isComplexApp := isAutoCorrectApp || isChrome
        
        pasteDelay := isComplexApp ? 200 : 50
        clipTimeout := 0.5

        oldClipboard := A_Clipboard
        A_Clipboard := ""
        
        isLineSelected := false

        ; 1. کپی متن ایمن
        SendInput("^c")
        
        if (ClipWait(0.5)) {
            text := A_Clipboard
        } else {
            isLineSelected := true
            SendInput("{Home}+{End}")
            A_Clipboard := ""
            SendInput("^c")
            if (!ClipWait(clipTimeout)) {
                A_Clipboard := ""
                SendInput("^a^c")
                if (!ClipWait(clipTimeout)) {
                    A_Clipboard := oldClipboard
                    ShowMessage("❌ متن یافت نشد", 1000)
                    return
                }
            }
            text := A_Clipboard
        }
        
        if (text == "") {
            A_Clipboard := oldClipboard
            ShowMessage("❌ متن یافت نشد", 1000)
            return
        }

        ; اصلاح حرف اول بزرگ در آفیس
        if (isAutoCorrectApp && RegExMatch(text, "^[A-Z][a-z]*")) {
            firstChar := SubStr(text, 1, 1)
            restOfText := SubStr(text, 2)
            text := StrLower(firstChar) . restOfText
        }

        ; شمارش فاصله‌های انتهایی
        spaceCount := 0
        if (RegExMatch(text, " +$", &match)) {
            spaceCount := StrLen(match[0])
        }

        trimmedText := Trim(text)
        if (trimmedText == "") {
            A_Clipboard := oldClipboard
            return
        }
        
        converted := transformeText(trimmedText, GetKeyMap())

        A_Clipboard := converted
        if (ClipWait(0.5)) {
            SendInput("^v")
            Sleep(pasteDelay)
        }

        if (spaceCount > 0) {
            Loop spaceCount {
                SendInput("{Space}")
            }
        }
        
        ; تنظیم جهت متن (RTL/LTR)
        if (isLineSelected && isAutoCorrectApp) {
            isPersian := RegExMatch(converted, "[\x{0600}-\x{06FF}]")
            if (isPersian) {
                SendInput("{RCtrl down}{RShift down}{RShift up}{RCtrl up}")
            } else {
                SendInput("{LCtrl down}{LShift down}{LShift up}{LCtrl up}")
            }
        }
        
        if (AutoSwitchLanguage) {
            SendInput("{Alt down}{Shift down}{Shift up}{Alt up}")
        }
        
        Sleep(100)
        A_Clipboard := oldClipboard
        ShowMessage("✅ متن تبدیل شد", 700)
    } finally {
        isRunning := false
    }
}


transformeLastWord() {
    static isRunning := false
    if (isRunning)
        return
    isRunning := true

    static lastCall := 0
    currentTime := A_TickCount
    
    if (currentTime - lastCall < 800) {
        isRunning := false
        return
    }
    lastCall := currentTime

    try {
        activeClass := ""
        try {
            activeClass := WinGetClass("A")
        } catch {
            activeClass := ""
        }

        isChrome := InStr(activeClass, "Chrome_WidgetWin_1")
        isWord := InStr(activeClass, "OpusApp") || InStr(activeClass, "Word")
        
        pasteDelay := isWord ? 400 : (isChrome ? 200 : 50)

        oldClipboard := A_Clipboard
        A_Clipboard := ""

        ; 1. تلاش برای کپی متن انتخاب شده ایمن
        SendInput("^c")
        
        wasFullSelect := false
        if (!ClipWait(0.5)) {
            SendInput("+{Home}")
            A_Clipboard := ""
            SendInput("^c")
            if (!ClipWait(0.5)) {
                A_Clipboard := oldClipboard
                return
            }
        } else {
            wasFullSelect := true
        }

        fullText := A_Clipboard
        fullText := StrReplace(fullText, "`r", "")
        fullText := StrReplace(fullText, "`n", "")
        
        trailingSpaces := ""
        if (RegExMatch(fullText, " +$", &trailMatch))
            trailingSpaces := trailMatch[0]

        trimmedText := RTrim(fullText)
        
        lastWord := ""
        prefix := ""
        if (RegExMatch(trimmedText, "(.* )([^ ]+)$", &match)) {
            prefix := match[1]
            lastWord := match[2]
        } else {
            lastWord := trimmedText
        }

        if (lastWord == "") {
            A_Clipboard := oldClipboard
            if (!wasFullSelect)
                SendInput("{Right}")
            return
        }

        converted := transformeText(lastWord, GetKeyMap())
        
        if (wasFullSelect) {
            A_Clipboard := prefix . converted
            if (ClipWait(0.5)) {
                SendInput("^v")
            }
        } else {
            SendInput("{Backspace}")
            Sleep(30)
            
            A_Clipboard := prefix . converted
            if (ClipWait(0.5)) {
                SendInput("^v")
            }
        }
        
        Sleep(pasteDelay)
        
        if (trailingSpaces != "") {
            SendInput("{Raw}" . trailingSpaces)
        }
        
        if (AutoSwitchLanguage2) {
            SendInput("{Alt down}{Shift down}{Shift up}{Alt up}")
        }
        
        Sleep(150)
        A_Clipboard := oldClipboard
    } finally {
        isRunning := false
    }
}
; ===============================================================
; Hotkey Management
; ===============================================================
SetupHotkey(hotkeyValue) {
    static currentHotkeyRef := ""
    
    if (currentHotkeyRef != "") {
        try Hotkey(currentHotkeyRef, "Off")
    }
    
    try {
        Hotkey(hotkeyValue, (*) => transformeHotkey(), "On")
        currentHotkeyRef := hotkeyValue
        return true
    }
    return false
}

SetupHotkey2(hotkeyValue) {
    static currentHotkeyRef := ""
    
    if (currentHotkeyRef != "") {
        try Hotkey(currentHotkeyRef, "Off")
    }
    
    try {
        Hotkey(hotkeyValue, (*) => transformeLastWord(), "On")
        currentHotkeyRef := hotkeyValue
        return true
    }
    return false
}

DisableAllHotkeys() {
    global CurrentHotkey, CurrentHotkey2
    try Hotkey(CurrentHotkey, "Off")
    try Hotkey(CurrentHotkey2, "Off")
}

EnableAllHotkeys() {
    global CurrentHotkey, CurrentHotkey2
    try Hotkey(CurrentHotkey, "On")
    try Hotkey(CurrentHotkey2, "On")
}
; ===============================================================
; Tray Menu
; ===============================================================
CreateTrayMenu() {
    A_TrayMenu.Delete()
    A_TrayMenu.Add("تنظیمات", (*) => ShowSettingsDialog())
    A_TrayMenu.Add("درباره", (*) => ShowAboutDialog())
    A_TrayMenu.Add("خروج", (*) => ExitApp())
}
; ===============================================================
; Settings Dialog
; ===============================================================
ShowSettingsDialog() {
    global CurrentHotkey, CurrentHotkey2, AutoSwitchLanguage, AutoSwitchLanguage2
    
    SettingsGui := Gui("+AlwaysOnTop", "تنظیمات")
    SettingsGui.SetFont("s10", "Segoe UI")
    
    SettingsGui.AddText("w400 Right Section", ":میان‌بر اول (برای تبدیل کل سطر یا متن انتخاب شده)")
    
    txtHotkey1 := SettingsGui.AddText("w400 Right", FormatHotkeyDisplay(CurrentHotkey) . " :میان‌بر فعلی")
    
    btnChange1 := SettingsGui.AddButton("w200", "تغییر میان‌بر")
    btnChange1.OnEvent("Click", (*) => ShowHotkeyDialog(1, txtHotkey1, SettingsGui))
    
    chkSwitch1 := SettingsGui.AddCheckbox("w400 Right Checked" . (AutoSwitchLanguage ? "" : "0"), "تغییر خودکار زبان پس از زدن میان‌بر")
    chkSwitch1.OnEvent("Click", (*) => SaveAutoSwitch(1, chkSwitch1.Value))
    
    SettingsGui.AddText("w400 Right", "")
    SettingsGui.AddText("w400 Right 0x10")
    SettingsGui.AddText("w400 Right", "")
    
    SettingsGui.AddText("w400 Right Section", ":میان‌بر دوم (برای تبدیل آخرین کلمه یا متن انتخاب شده)")
    
    txtHotkey2 := SettingsGui.AddText("w400 Right", FormatHotkeyDisplay(CurrentHotkey2) . " :میان‌بر فعلی")
    
    btnChange2 := SettingsGui.AddButton("w200", "تغییر میان‌بر")
    btnChange2.OnEvent("Click", (*) => ShowHotkeyDialog(2, txtHotkey2, SettingsGui))
    
    chkSwitch2 := SettingsGui.AddCheckbox("w400 Right Checked" . (AutoSwitchLanguage2 ? "" : "0"), "تغییر خودکار زبان پس از زدن میان‌بر")
    chkSwitch2.OnEvent("Click", (*) => SaveAutoSwitch(2, chkSwitch2.Value))
    
    SettingsGui.AddText("w400 Right", "")
    SettingsGui.AddText("w400 Right 0x10")
    SettingsGui.AddText("w400 Right", "")
    
    chkStartup := SettingsGui.AddCheckbox("w400 Right Checked" . (IsStartupEnabled() ? "" : "0"), "اجرای خودکار با ویندوز")
    chkStartup.OnEvent("Click", (*) => ToggleStartupFromSettings(chkStartup))
    
    SettingsGui.AddText("w400 Right", "")
    btnReset := SettingsGui.AddButton("w200", "بازگشت به تنظیمات پیش‌فرض")
    btnReset.OnEvent("Click", (*) => ResetToDefaults(SettingsGui, txtHotkey1, txtHotkey2, chkSwitch1, chkSwitch2))
    
    SettingsGui.txtHotkey1 := txtHotkey1
    SettingsGui.txtHotkey2 := txtHotkey2
    
    SettingsGui.OnEvent("Escape", (*) => SettingsGui.Destroy())
    SettingsGui.OnEvent("Close", (*) => SettingsGui.Destroy())
    
    SettingsGui.Show()
}

ResetToDefaults(guiObj, txt1, txt2, chk1, chk2) {
    global CurrentHotkey, CurrentHotkey2, AutoSwitchLanguage, AutoSwitchLanguage2
    
    result := MsgBox("آیا مطمئن هستید که می‌خواهید به تنظیمات پیش‌فرض بازگردید؟", "تایید", "0x24 Owner" . guiObj.Hwnd)
    
    if (result = "Yes") {
        try Hotkey(CurrentHotkey, "Off")
        try Hotkey(CurrentHotkey2, "Off")
        
        CurrentHotkey := "F8"
        CurrentHotkey2 := "F9"
        AutoSwitchLanguage := true
        AutoSwitchLanguage2 := false
        
        Config.WriteHotkey("F8")
        Config.WriteHotkey2("F9")
        Config.WriteAutoSwitch(true)
        Config.WriteAutoSwitch2(false)
        
        SetupHotkey("F8")
        SetupHotkey2("F9")
        
        if (!HotkeysEnabled) {
            DisableAllHotkeys()
        }
        
        txt1.Value := FormatHotkeyDisplay("F8") . " :میان‌بر فعلی"
        txt2.Value := FormatHotkeyDisplay("F9") . " :میان‌بر فعلی"
        chk1.Value := 1
        chk2.Value := 0
        
        ShowMessage("✅ تنظیمات به حالت پیش‌فرض بازگشت", 1500)
    }
}

SaveAutoSwitch(switchNum, value) {
    global AutoSwitchLanguage, AutoSwitchLanguage2
    
    if (switchNum = 1) {
        AutoSwitchLanguage := value
        Config.WriteAutoSwitch(value)
    } else {
        AutoSwitchLanguage2 := value
        Config.WriteAutoSwitch2(value)
    }
}

ToggleStartupFromSettings(checkboxCtrl) {
    if (checkboxCtrl.Value) {
        if (EnableStartup()) {
            ShowMessage("✅ اجرای خودکار فعال شد", 1500)
        } else {
            checkboxCtrl.Value := 0
            ShowMessage("❌ خطا در فعال‌سازی اجرای خودکار", 1500)
        }
    } else {
        if (DisableStartup()) {
            ShowMessage("❌ اجرای خودکار غیرفعال شد", 1500)
        } else {
            checkboxCtrl.Value := 1
            ShowMessage("❌ خطا در غیرفعال‌سازی اجرای خودکار", 1500)
        }
    }
}

ShowHotkeyDialog(hotkeyNum, txtControl, parentGui) {
    global CurrentHotkey, CurrentHotkey2
    
    selectedHotkey := (hotkeyNum = 1) ? CurrentHotkey : CurrentHotkey2
    
    HotkeyGui := Gui("+AlwaysOnTop +Owner" . parentGui.Hwnd, "تغییر میان‌بر")
    HotkeyGui.SetFont("s10", "Segoe UI")
    
    HotkeyGui.AddText("w380 Right", FormatHotkeyDisplay(selectedHotkey) . " :میان‌بر فعلی")
    HotkeyGui.AddText("w380 y+15 cGray Right", ":ترکیب کلید دلخواه خود را فشار دهید")
    
    statusText := HotkeyGui.AddText("w380 y+10 h60 Border Center 0x200", "در انتظار فشردن کلید...")
    statusText.SetFont("s11 bold")
    
    HotkeyGui.AddText("w380 y+15 cGray Right", ":می‌توانید از ترکیب کلیدها استفاده کنید`n Ctrl+Alt+A یا Shift+F5 :مثال")
    
    btnCancel := HotkeyGui.AddButton("w185 y+20", "✕ انصراف")
    btnOK := HotkeyGui.AddButton("w185 x+10 yp", "✓ تایید")
    
    HotkeyGui.capturedKey := ""
    HotkeyGui.pressedKeys := Map()
    HotkeyGui.statusText := statusText
    HotkeyGui.hotkeyNum := hotkeyNum
    HotkeyGui.txtControl := txtControl
    HotkeyGui.parentGui := parentGui
    
    btnOK.OnEvent("Click", (*) => ApplyTempHotkey(HotkeyGui))
    btnCancel.OnEvent("Click", (*) => CloseHotkeyDialog(HotkeyGui))
    
    HotkeyGui.OnEvent("Escape", (*) => CloseHotkeyDialog(HotkeyGui))
    HotkeyGui.OnEvent("Close", (*) => CloseHotkeyDialog(HotkeyGui))
    
    HotkeyGui.keyboardHook := InputHook("L0 V")
    HotkeyGui.keyboardHook.KeyOpt("{All}", "N")
    HotkeyGui.keyboardHook.KeyOpt("{LWin}", "-S")
    HotkeyGui.keyboardHook.KeyOpt("{RWin}", "-S")
    
    HotkeyGui.keyboardHook.OnKeyDown := KeyDownHandler.Bind(HotkeyGui)
    HotkeyGui.keyboardHook.OnKeyUp := KeyUpHandler.Bind(HotkeyGui)
    
    HotkeyGui.Show()
    HotkeyGui.keyboardHook.Start()
}

KeyDownHandler(guiObj, ihObj, vk, sc) {
    keyName := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
    keyName := NormalizeKeyName(keyName)
    
    if (keyName ~= "i)^(Control|Ctrl|Shift|Alt|Win)$")
        return
    
    guiObj.pressedKeys[keyName] := true
    
    modifiers := ""
    ctrlPressed := (GetKeyState("LCtrl", "P") || GetKeyState("RCtrl", "P"))
    shiftPressed := (GetKeyState("LShift", "P") || GetKeyState("RShift", "P"))
    altPressed := (GetKeyState("LAlt", "P") || GetKeyState("RAlt", "P"))
    winPressed := (GetKeyState("LWin", "P") || GetKeyState("RWin", "P"))
    
    if ctrlPressed
        modifiers .= "^"
    if shiftPressed
        modifiers .= "+"
    if altPressed
        modifiers .= "!"
    if winPressed
        modifiers .= "#"
    
    if (StrLen(keyName) = 1 && keyName ~= "[A-Z]") {
        if (shiftPressed && !ctrlPressed && !altPressed && !winPressed) {
            keyName := Format("{:L}", keyName)
            modifiers := StrReplace(modifiers, "+", "")
        }
    }
    
    hotkeyString := modifiers . keyName
    guiObj.capturedKey := hotkeyString
    
    displayText := FormatHotkeyDisplay(hotkeyString)
    guiObj.statusText.Value := "کلید انتخاب شده:`n" . displayText
    guiObj.statusText.SetFont("s12 bold cGreen")
}

KeyUpHandler(guiObj, ihObj, vk, sc) {
    try {
        keyName := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
        if (keyName = "")
            return
            
        keyName := NormalizeKeyName(keyName)
        
        if (guiObj.pressedKeys.Has(keyName)) {
            guiObj.pressedKeys.Delete(keyName)
        }
    } catch {
        return
    }
}

NormalizeKeyName(keyName) {
    keyName := StrReplace(keyName, "LControl", "Ctrl")
    keyName := StrReplace(keyName, "RControl", "Ctrl")
    keyName := StrReplace(keyName, "LShift", "Shift")
    keyName := StrReplace(keyName, "RShift", "Shift")
    keyName := StrReplace(keyName, "LAlt", "Alt")
    keyName := StrReplace(keyName, "RAlt", "Alt")
    keyName := StrReplace(keyName, "LWin", "Win")
    keyName := StrReplace(keyName, "RWin", "Win")
    return keyName
}

CloseHotkeyDialog(guiObj) {
    try {
        if (guiObj.HasProp("keyboardHook")) {
            try guiObj.keyboardHook.Stop()
            guiObj.keyboardHook := ""
        }
    }
    guiObj.Destroy()
}

ApplyTempHotkey(guiObj) {
    global CurrentHotkey, CurrentHotkey2
    
    if (guiObj.capturedKey = "") {
        WinSetAlwaysOnTop(1, guiObj.parentGui.Hwnd)
        MsgBox("لطفا ابتدا یک کلید میان‌بر را فشار دهید.", "توجه", "0x30 Owner" . guiObj.parentGui.Hwnd)
        return
    }
    
    if (guiObj.hotkeyNum = 1) {
        if (guiObj.capturedKey = CurrentHotkey2) {
            WinSetAlwaysOnTop(1, guiObj.parentGui.Hwnd)
            MsgBox("این میان‌بر قبلا برای میان‌بر دوم استفاده شده است!`n`nلطفا میان‌بر دیگری انتخاب کنید.", "خطا", "0x10 Owner" . guiObj.parentGui.Hwnd)
            return
        }
    } else {
        if (guiObj.capturedKey = CurrentHotkey) {
            WinSetAlwaysOnTop(1, guiObj.parentGui.Hwnd)
            MsgBox("این میان‌بر قبلا برای میان‌بر اول استفاده شده است!`n`nلطفا میان‌بر دیگری انتخاب کنید.", "خطا", "0x10 Owner" . guiObj.parentGui.Hwnd)
            return
        }
    }
    
    try {
        if (guiObj.HasProp("keyboardHook")) {
            try guiObj.keyboardHook.Stop()
            guiObj.keyboardHook := ""
        }
    }
    
    if (guiObj.hotkeyNum = 1) {
        try Hotkey(CurrentHotkey, "Off")
        if SetupHotkey(guiObj.capturedKey) {
            CurrentHotkey := guiObj.capturedKey
            Config.WriteHotkey(guiObj.capturedKey)
            guiObj.txtControl.Value := FormatHotkeyDisplay(guiObj.capturedKey) . " :میان‌بر فعلی"
            guiObj.Destroy()
            ShowMessage("✅ میان‌بر اول تغییر کرد", 1500)
        } else {
            SetupHotkey(CurrentHotkey)
            WinSetAlwaysOnTop(1, guiObj.parentGui.Hwnd)
            MsgBox("خطا در تنظیم میان‌بر!", "خطا", "0x10 Owner" . guiObj.parentGui.Hwnd)
            guiObj.Destroy()
        }
    } else {
        try Hotkey(CurrentHotkey2, "Off")
        if SetupHotkey2(guiObj.capturedKey) {
            CurrentHotkey2 := guiObj.capturedKey
            Config.WriteHotkey2(guiObj.capturedKey)
            guiObj.txtControl.Value := FormatHotkeyDisplay(guiObj.capturedKey) . " :میان‌بر فعلی"
            guiObj.Destroy()
            ShowMessage("✅ میان‌بر دوم تغییر کرد", 1500)
        } else {
            SetupHotkey2(CurrentHotkey2)
            WinSetAlwaysOnTop(1, guiObj.parentGui.Hwnd)
            MsgBox("خطا در تنظیم میان‌بر!", "خطا", "0x10 Owner" . guiObj.parentGui.Hwnd)
            guiObj.Destroy()
        }
    }
}

FormatHotkeyDisplay(hotkey) {
    display := hotkey
    display := StrReplace(display, "^", "<<<CTRL>>>")
    display := StrReplace(display, "!", "<<<ALT>>>")
    display := StrReplace(display, "+", "<<<SHIFT>>>")
    display := StrReplace(display, "#", "<<<WIN>>>")
    display := StrReplace(display, "<<<CTRL>>>", "Ctrl+")
    display := StrReplace(display, "<<<ALT>>>", "Alt+")
    display := StrReplace(display, "<<<SHIFT>>>", "Shift+")
    display := StrReplace(display, "<<<WIN>>>", "Win+")
    return display
}

; ===============================================================
; Shared Dialog Helpers
; ===============================================================
GetInfoTextLines() {
    return [
        ".می‌باشد F8 کلید میان‌بر اول پیش‌فرض",
        ".می‌باشد F9 کلید میان‌بر دوم پیش‌فرض",
        ".می‌توانید از منوی تنظیمات میان‌بر ها را تغییردهید"
    ]
}

; ===============================================================
; First Run Dialog
; ===============================================================
ShowFirstRunDialog() {
    FirstRunGui := Gui("+AlwaysOnTop", "خوش آمدید")
    FirstRunGui.SetFont("s10", "Segoe UI")
    
    for text in GetInfoTextLines() {
        FirstRunGui.AddText("w350 Right", text)
    }
    
    chkStartup := FirstRunGui.AddCheckbox("w350 y+20 Right Checked", "اجرای خودکار با ویندوز")
    chkStartup.OnEvent("Click", (*) => ToggleStartupFromFirstRun(chkStartup))
    
    ; فعال‌سازی startup به صورت پیش‌فرض اگر قبلاً فعال نشده باشد
    if (!IsStartupEnabled()) {
        EnableStartup()
    }
    
    chkDontShow := FirstRunGui.AddCheckbox("w350 y+10 Right Checked", "این پیام را دیگر نشان نده")
    
    btnOK := FirstRunGui.AddButton("w100 y+20 Default", "متوجه شدم")
    btnOK.OnEvent("Click", (*) => CloseFirstRunDialog(FirstRunGui, chkDontShow))
    
    FirstRunGui.OnEvent("Escape", (*) => CloseFirstRunDialog(FirstRunGui, chkDontShow))
    
    FirstRunGui.Show()
}

CloseFirstRunDialog(guiObj, checkboxCtrl) {
    if (checkboxCtrl.Value) {
        Config.SetFirstRunComplete()
    }
    guiObj.Destroy()
}

ToggleStartupFromFirstRun(checkboxCtrl) {
    if (checkboxCtrl.Value) {
        if (!EnableStartup()) {
            checkboxCtrl.Value := 0
            ShowMessage("❌ خطا در فعال‌سازی اجرای خودکار", 1500)
        }
    } else {
        if (!DisableStartup()) {
            checkboxCtrl.Value := 1
            ShowMessage("❌ خطا در غیرفعال‌سازی اجرای خودکار", 1500)
        }
    }
}

; ===============================================================
; About Dialog
; ===============================================================
ShowAboutDialog() {
    AboutGui := Gui("+AlwaysOnTop", "درباره")
    AboutGui.SetFont("s10", "Segoe UI")
    
    for text in GetInfoTextLines() {
        AboutGui.AddText("w350 Right", text)
    }
    AboutGui.AddText("w350 Left", "v1.0 by mehdi.mahmoudi@gmail.com")

    
    btnOK := AboutGui.AddButton("w100 y+20 Default", "متوجه شدم")
    btnOK.OnEvent("Click", (*) => AboutGui.Destroy())
    
    AboutGui.OnEvent("Escape", (*) => AboutGui.Destroy())
    
    AboutGui.Show()
}

; ===============================================================
; Initialization
; ===============================================================
CreateTrayMenu()

SetCustomTrayIcon()

if (Config.IsFirstRun()) {
    ShowFirstRunDialog()
}

if (!SetupHotkey(CurrentHotkey)) {
    CurrentHotkey := "F8"
    Config.WriteHotkey("F8")
    SetupHotkey("F8")
}

if (!SetupHotkey2(CurrentHotkey2)) {
    CurrentHotkey2 := "F9"
    Config.WriteHotkey2("F9")
    SetupHotkey2("F9")
}

Persistent
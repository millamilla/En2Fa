#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn
#Hotstring O
#Hotstring NoMouse

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
    FileInstall("Enable.ico", A_Temp "\Enable.ico", 1)
    FileInstall("Disable.ico", A_Temp "\Disable.ico", 1)
    TrayIconActive := A_Temp "\Enable.ico"
    TrayIconDisabled := A_Temp "\Disable.ico"
} else {
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
    ; استفاده از نام فایل بدون پسوند برای تشخیص نسخه‌های مختلف
    name := A_ScriptName
    name := RegExReplace(name, "\.exe$", "")
    return "PersianTranslator_" . name
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
            A_TrayMenu.Uncheck("اجرای خودکار با ویندوز")
        }
    } else {
        if (EnableStartup()) {
            ShowMessage("✅ اجرای خودکار فعال شد", 1500)
            A_TrayMenu.Check("اجرای خودکار با ویندوز")
        }
    }
}

UpdateStartupMenuItem() {
    try A_TrayMenu.Delete("اجرای خودکار با ویندوز")
    A_TrayMenu.Insert("درباره", "اجرای خودکار با ویندوز", ToggleStartup)
    if (IsStartupEnabled()) {
        A_TrayMenu.Check("اجرای خودکار با ویندوز")
    } else {
        A_TrayMenu.Uncheck("اجرای خودکار با ویندوز")
    }
}

; ===============================================================
; Auto-Fix Registry Path on File Move
; ===============================================================
FixStartupPathAfterMove() {
    local regPath := GetStartupRegistryPath()
    local valueName := GetStartupValueName()
    local currentExePath := A_ScriptFullPath
    
    if (IsStartupEnabled()) {
        try {
            storedPath := RegRead(regPath, valueName)
            if (storedPath != currentExePath) {
                if (A_IsCompiled) {
                    RegWrite(currentExePath, "REG_SZ", regPath, valueName)
                } else {
                    RegWrite('"' A_AhkPath '" "' currentExePath '"', "REG_SZ", regPath, valueName)
                }
                ShowMessage("🔄 مسیر اجرایی به‌روزرسانی شد", 1500)
            }
        } catch {
            ; ignore
        }
    }
}

; ===============================================================
; ساخت منوی System Tray و مدیریت کلیک‌ها
; ===============================================================

OnMessage(0x404, HandleTrayClick)

HandleTrayClick(wParam, lParam, msg, hwnd) {
    try {
        if (lParam = 0x201)
            ToggleHotkeys()
    }
}

ToggleHotkeys() {
    global HotkeysEnabled, TrayIconActive, TrayIconDisabled
    global TrayIconActiveIndex, TrayIconDisabledIndex

    if (HotkeysEnabled) {
        ; 1. غیرفعال کردن هات‌کی‌های F8 و F9
        DisableAllHotkeys()
        ; 2. غیرفعال کردن میان‌بر‌های متنی
        ShortcutManager.DisableAll()
        
        HotkeysEnabled := false

        ; تغییر آیکون به حالت غیرفعال
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
        ShowMessage("⛔ همه‌ی تبدیل‌ها غیرفعال شدند", 1500)
    } else {
        ; 1. فعال کردن هات‌کی‌های F8 و F9
        EnableAllHotkeys()
        ; 2. فعال کردن مجدد میان‌بر‌های متنی
        ShortcutManager.LoadAndEnable()
        
        HotkeysEnabled := true

        ; تغییر آیکون به حالت فعال
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
        ShowMessage("✅ همه‌ی تبدیل‌ها فعال شدند", 1500)
    }
}

; ===============================================================
; تابع برای تنظیم آیکون دلخواه
; ===============================================================
SetCustomTrayIcon() {
    global TrayIconActive, TrayIconActiveIndex
    if (FileExist(TrayIconActive) && !InStr(TrayIconActive, ".dll")) {
        try {
            TraySetIcon(TrayIconActive)
            return true
        }
    }
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
    
    ; --- English digits to Persian ---
    m["0"] := "۰"
    m["1"] := "۱"
    m["2"] := "۲"
    m["3"] := "۳"
    m["4"] := "۴"
    m["5"] := "۵"
    m["6"] := "۶"
    m["7"] := "۷"
    m["8"] := "۸"
    m["9"] := "۹"
    
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
    
    ; --- Persian digits to English ---
    m["۰"] := "0"
    m["۱"] := "1"
    m["۲"] := "2"
    m["۳"] := "3"
    m["۴"] := "4"
    m["۵"] := "5"
    m["۶"] := "6"
    m["۷"] := "7"
    m["۸"] := "8"
    m["۹"] := "9"
    
    return m
}

; ===============================================================
; Helper Functions - Optimized
; ===============================================================
GetCharScore(char) {
    if (char == "")
        return 0
    static neutralChars := Map(" ", 0, ".", 0, ",", 0, "!", 0, "?", 0, 
                               ":", 0, ";", 0, "-", 0, "_", 0, "=", 0,
                               "/", 0, "\", 0, "(", 0, ")", 0, "[", 0, "]", 0,
                               "{", 0, "}", 0, "@", 0, "#", 0, "$", 0, "%", 0,
                               "^", 0, "&", 0, "*", 0, "+", 0, "|", 0, "<", 0, ">", 0)
    if (neutralChars.Has(char))
        return 0
    code := Ord(char)
    if ((code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A))
        return 1
    if (code >= 0x600 && code <= 0x6FF)
        return -1
    if ((code >= 0x30 && code <= 0x39) || (code >= 0x06F0 && code <= 0x06F9))
        return 0
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

; ===============================================================
; اصلاح تابع transformText با اضافه کردن پارامتر defaultLang
; و حذف شاخه‌های تکراری
; ===============================================================
transformText(text, map, defaultLang := "") {
    result := ""
    chars := StrSplit(text)
    len := chars.Length
    ; اگر زبان مشخص نشده یک بار تشخیص بده
    if (defaultLang = "") {
        defaultLang := DetectTextLanguage(text)
    }
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
                ; استفاده از defaultLang به جای فراخوانی تکراری DetectTextLanguage
                if (defaultLang = "EN")
                    result .= GetEnglishContextChar(char)
                else if (defaultLang = "FA")
                    result .= GetPersianContextChar(char)
                else
                    result .= char
            }
        }
        ; حذف else if اضافی و ادغام در else
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
; اصلاح نام توابع: transformeHotkey -> transformHotkey
; و تغییر lastCall به 350ms و بازیابی کلیپ‌بورد در finally
; ===============================================================
transformHotkey() {
    static isRunning := false
    if (isRunning)
        return
    isRunning := true
    static lastCall := 0
    currentTime := A_TickCount
    if (currentTime - lastCall < 350) {   ; کاهش از 800 به 350
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
        if (isAutoCorrectApp && RegExMatch(text, "^[A-Z][a-z]*")) {
            firstChar := SubStr(text, 1, 1)
            restOfText := SubStr(text, 2)
            text := StrLower(firstChar) . restOfText
        }
        spaceCount := 0
        if (RegExMatch(text, " +$", &match)) {
            spaceCount := StrLen(match[0])
        }
        trimmedText := Trim(text)
        if (trimmedText == "") {
            A_Clipboard := oldClipboard
            return
        }
        ; تشخیص زبان یک بار قبل از تبدیل
        lang := DetectTextLanguage(trimmedText)
        converted := transformText(trimmedText, GetKeyMap(), lang)
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
        ShowMessage("✅ متن تبدیل شد", 700)
    } finally {
        ; بازیابی کلیپ‌بورد در finally
        A_Clipboard := oldClipboard
        isRunning := false
    }
}

; ===============================================================
; اصلاح نام تابع transformeLastWord -> transformLastWord
; و تغییر lastCall به 350ms و بازیابی کلیپ‌بورد در finally
; ===============================================================
transformLastWord() {
    static isRunning := false
    if (isRunning)
        return
    isRunning := true
    static lastCall := 0
    currentTime := A_TickCount
    if (currentTime - lastCall < 350) {   ; کاهش از 800 به 350
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
        ; تشخیص زبان یک بار قبل از تبدیل
        lang := DetectTextLanguage(lastWord)
        converted := transformText(lastWord, GetKeyMap(), lang)
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
    } finally {
        A_Clipboard := oldClipboard
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
        Hotkey(hotkeyValue, (*) => transformHotkey(), "On")
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
        Hotkey(hotkeyValue, (*) => transformLastWord(), "On")
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
; ساخت منوی System Tray 
; ===============================================================
CreateTrayMenu() {
    A_TrayMenu.Delete()
	A_TrayMenu.Add("اجرای خودکار با ویندوز", ToggleStartup)
    if (IsStartupEnabled())
        A_TrayMenu.Check("اجرای خودکار با ویندوز")
    A_TrayMenu.Add("تبدیل دلخواه", (*) => ShortcutManager.ShowGUI())
    A_TrayMenu.Add("تنظیمات ", (*) => ShowSettingsDialog())
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
        ".می‌توانید از منوی تنظیمات میان‌بر ها را تغییردهید",
	".برای تعیین عبارات جایگزین میتوانید از منوی تبدیل دلخواه استفاده کنید"
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

    AboutGui.AddText("w350 Left", "v2.0 by mehdi.mahmoudi@gmail.com")
    btnOK := AboutGui.AddButton("w100 y+20 Default", "متوجه شدم")
    btnOK.OnEvent("Click", (*) => AboutGui.Destroy())
    AboutGui.OnEvent("Escape", (*) => AboutGui.Destroy())
    AboutGui.Show()
}
; ===============================================================
; Shortcut Manager (Hotstring-based Text Expansions) with Date Support
; ===============================================================

class ShortcutManager {
    static IniFile := A_ScriptDir "\En2Fa.ini"   ; استفاده از فایل تنظیمات مشترک
    static ActiveKeys := []
    static GuiObj := ""

    ; ===============================================================
    ; لیست فرمت‌های تاریخ و زمان
    ; ===============================================================
    static DateFormats := [
        "میلادی:yyyy-MM-dd",
        "میلادی:dd/MM/yyyy",
        "میلادی:MM/dd/yyyy",
        "میلادی:dd MMM yyyy",
        "میلادی:dddd dd MMMM yyyy",
        "میلادی:yyyy-MM-dd HH:mm:ss",
        "میلادی:HH:mm:ss",
        "میلادی:HH:mm",
        "میلادی:hh:mm tt",
		"شمسی:yyyy-MM-dd",
        "شمسی:yyyy/MM/dd",
        "شمسی:dd/MM/yyyy",
        "شمسی:dd MMM yyyy",
        "شمسی:dddd dd MMMM yyyy",
        "Custom"
    ]

    ; ===============================================================
    ; نام ماه‌های شمسی (یک آرایه کافی است)
    ; ===============================================================
    static JalaliMonthNames := [
        "فروردین",
        "اردیبهشت",
        "خرداد",
        "تیر",
        "مرداد",
        "شهریور",
        "مهر",
        "آبان",
        "آذر",
        "دی",
        "بهمن",
        "اسفند"
    ]

    ; ===============================================================
    ; نام روزهای هفته (یک آرایه کافی است)
    ; ===============================================================
    static JalaliWeekDays := [
        "یک‌شنبه",
        "دوشنبه",
        "سه‌شنبه",
        "چهارشنبه",
        "پنجشنبه",
        "جمعه",
        "شنبه"
    ]

    ; ===============================================================
    ; تبدیل تاریخ میلادی به شمسی
    ; ===============================================================
    static GetJalaliDate(fmt := "yyyy/MM/dd") {
        g_y := Integer(FormatTime(A_Now, "yyyy"))
        g_m := Integer(FormatTime(A_Now, "MM"))
        g_d := Integer(FormatTime(A_Now, "dd"))

        g_days_in_month := [
            31, 28, 31, 30, 31, 30,
            31, 31, 30, 31, 30, 31
        ]

        j_days_in_month := [
            31, 31, 31, 31, 31, 31,
            30, 30, 30, 30, 30, 29
        ]

        if ((Mod(g_y, 4) == 0 && Mod(g_y, 100) != 0)
            || Mod(g_y, 400) == 0) {
            g_days_in_month[2] := 29
        }

        gy := g_y - 1600
        gm := g_m - 1
        gd := g_d - 1

        g_day_no :=
            365 * gy
            + Floor((gy + 3) / 4)
            - Floor((gy + 99) / 100)
            + Floor((gy + 399) / 400)

        Loop gm {
            g_day_no += g_days_in_month[A_Index]
        }

        g_day_no += gd

        j_day_no := g_day_no - 79

        j_np := Floor(j_day_no / 12053)
        j_day_no := Mod(j_day_no, 12053)

        jy := 979
            + 33 * j_np
            + 4 * Floor(j_day_no / 1461)

        j_day_no := Mod(j_day_no, 1461)

        if (j_day_no >= 365) {
            jy += Floor((j_day_no - 1) / 365)
            j_day_no := Mod(j_day_no - 1, 365)
        }

        jm := 1

        Loop 11 {
            if (j_day_no < j_days_in_month[A_Index]) {
                jm := A_Index
                break
            }

            j_day_no -= j_days_in_month[A_Index]
            jm := A_Index + 1
        }

        jd := j_day_no + 1

        weekDayIndex := Integer(FormatTime(A_Now, "WDay"))
        weekDayName := this.JalaliWeekDays[weekDayIndex]

        jyStr := Format("{:04d}", jy)
        jmStr := Format("{:02d}", jm)
        jdStr := Format("{:02d}", jd)

        monthName := this.JalaliMonthNames[jm]

        res := fmt
        res := StrReplace(res, "yyyy", jyStr)
        res := StrReplace(res, "MMMM", monthName)
        res := StrReplace(res, "MMM", monthName)  ; برای کوتاه از همان نام کامل استفاده می‌شود
        res := StrReplace(res, "dddd", weekDayName)
        res := StrReplace(res, "ddd", weekDayName)
        res := StrReplace(res, "MM", jmStr)
        res := StrReplace(res, "dd", jdStr)

        if InStr(fmt, "MMM") || InStr(fmt, "MMMM") {
            res := Chr(0x200F) . res . Chr(0x200F)
        }
		res := StrReplace(res, "{space}", " ")
        return res
    }


    ; ===============================================================
    ; دریافت تاریخ میلادی
    ; ===============================================================
static GetDate(dateFormat, endChar := "") {
        dateFormat := Trim(dateFormat)

        if (dateFormat = "" || dateFormat = "Custom") {
            dateFormat := "yyyy-MM-dd"
        }

        ; جایگزینی {space} پیش از ارسال به FormatTime
        dateFormat := StrReplace(dateFormat, "{space}", " ")

        try {
            result := FormatTime(A_Now, dateFormat)

            if (result = "") {
                return FormatTime(A_Now, "yyyy-MM-dd")
            }

            return result

        } catch {
            return FormatTime(A_Now, "yyyy-MM-dd")
        }
    }



; ===============================================================
    ; ارسال تاریخ شمسی بدون درگیری کلیپ‌بورد
    ; ===============================================================
    static SendJalaliDate(text) {
        SendText(text)
    }


    ; ===============================================================
    ; ساخت Callback برای تاریخ
    ; ===============================================================
static MakeDateCallback(dateFormat) {

        cleanFormat := Trim(dateFormat)
        cleanFormat := StrReplace(cleanFormat, "📅", "")
        cleanFormat := Trim(cleanFormat)

        if InStr(cleanFormat, "شمسی") {
            realFormat := Trim(RegExReplace(cleanFormat, "^شمسی:\s*", ""))
            if (realFormat = "" || realFormat = "Custom") {
                realFormat := "yyyy/MM/dd"
            }
            return (*) => this.SendJalaliDate(this.GetJalaliDate(realFormat))
        }
        else if InStr(cleanFormat, "میلادی") {
            realFormat := Trim(RegExReplace(cleanFormat, "^میلادی:\s*", ""))
            if (realFormat = "" || realFormat = "Custom") {
                realFormat := "yyyy-MM-dd"
            }
            return (*) => SendText(this.GetDate(realFormat))
        }
        else {
            return (*) => SendText(this.GetDate(cleanFormat))
        }
    }


    ; ===============================================================
    ; تبدیل میان‌بر برای ذخیره‌سازی
    ; ===============================================================
    static EncodeShortcut(short) {
        return StrReplace(short, " ", "{space}")
    }

    static DecodeShortcut(encoded) {
        return StrReplace(encoded, "{space}", " ")
    }


    ; ===============================================================
    ; بارگذاری و فعال‌سازی میان‌بر‌ها
    ; ===============================================================
    static LoadAndEnable() {

        this.DisableAll()

        if !FileExist(this.IniFile) {
            ShowMessage(
                "⚠️ فایل En2Fa.ini یافت نشد",
                2000
            )
            return
        }

        count := 0
        inShortcutsSection := false

        try {

            loop read, this.IniFile {

                line := Trim(A_LoopReadLine)

                if (line = "")
                    continue

                ; تشخیص بخش
                if (SubStr(line, 1, 1) = "[") {
                    inShortcutsSection := (line = "[Shortcuts]")
                    continue
                }

                if !inShortcutsSection
                    continue

                if InStr(line, "=") {

                    eqPos := InStr(line, "=")

                    encodedShort :=
                        Trim(
                            SubStr(
                                line,
                                1,
                                eqPos - 1
                            )
                        )

                    repl :=
                        Trim(
                            SubStr(
                                line,
                                eqPos + 1
                            )
                        )

                    short :=
                        this.DecodeShortcut(encodedShort)

                    if (short != "" && repl != "") {

                        this.EnableShortcut(
                            short,
                            repl
                        )

                        count++
                    }
                }
            }

            ShowMessage(
                "✅ " . count . " میان‌بر بارگذاری شد",
                1500
            )

        } catch as err {

            ShowMessage(
                "❌ خطا در بارگذاری: " . err.Message,
                3000
            )
        }
    }


    ; ===============================================================
    ; فعال‌سازی یک میان‌بر
    ; ===============================================================
    static EnableShortcut(short, repl) {

        try Hotstring(":*O:" . short, "Off")
        try Hotstring(":*X:" . short, "Off")

        ; -----------------------------------------------------------
        ; میان‌بر تاریخ
        ; -----------------------------------------------------------
        if (InStr(repl, "{date:") = 1) {

            dateFormat :=
                SubStr(
                    repl,
                    7,
                    -1
                )

            dateFormat := Trim(dateFormat)

            if (dateFormat = "" || dateFormat = "Custom") {
                dateFormat := "میلادی:yyyy-MM-dd"
            }

            hotstringDef := ":*X:" . short

            try {

                callbackFunc :=
                    this.MakeDateCallback(
                        dateFormat
                    )

                Hotstring(
                    hotstringDef,
                    callbackFunc,
                    "On"
                )

                this.ActiveKeys.Push(short)

            } catch as err {

                ShowMessage(
                    "❌ خطا در فعال‌سازی '"
                    . short
                    . "': "
                    . err.Message,
                    3000
                )
            }

        } else {

            ; -------------------------------------------------------
            ; میان‌بر معمولی
            ; -------------------------------------------------------
hotstringDef := ":*OT:" . short

        try {
            ; تبدیل کلمه کلیدی به فاصله واقعی پیش از اجرا
            actualRepl := StrReplace(repl, "{space}", " ")

            Hotstring(
                hotstringDef,
                actualRepl,
                "On"
            )

                this.ActiveKeys.Push(short)

            } catch as err {

                ShowMessage(
                    "❌ خطا در فعال‌سازی '"
                    . short
                    . "': "
                    . err.Message,
                    3000
                )
            }
        }
    }


    ; ===============================================================
    ; غیرفعال کردن همه میان‌بر‌ها
    ; ===============================================================
    static DisableAll() {
        for short in this.ActiveKeys {
            try Hotstring(":*O:" . short, , "Off")
            try Hotstring(":*X:" . short, , "Off")
            try Hotstring("::" . short, , "Off")
        }
        this.ActiveKeys := []
    }

    ; ===============================================================
    ; Reload
    ; ===============================================================
    static Reload() {
        this.DisableAll()
        this.LoadAndEnable()
    }


    ; ===============================================================
    ; ذخیره میان‌بر
    ; ===============================================================
    static SaveShortcut(short, repl) {
        
        ; جلوگیری از مشکل علامت سوال با ایجاد فایل به صورت یونیکد
        if !FileExist(this.IniFile) {
            FileAppend("", this.IniFile, "UTF-16")
        }

        this.DeleteShortcutFromIni(short)

        encodedShort := this.EncodeShortcut(short)

        IniWrite(repl, this.IniFile, "Shortcuts", encodedShort)

        this.Reload()
    }


    ; ===============================================================
    ; حذف میان‌بر از INI
    ; ===============================================================
    static DeleteShortcutFromIni(short) {

        try {

            encodedShort :=
                this.EncodeShortcut(short)

            IniDelete(
                this.IniFile,
                "Shortcuts",
                encodedShort
            )

            this.Reload()

        } catch {
            ; ignore
        }
    }


    ; ===============================================================
    ; دریافت تمام میان‌بر‌ها
    ; ===============================================================
    static GetAllShortcuts() {

        items := []

        if !FileExist(this.IniFile)
            return items

        try {

            inShortcutsSection := false

            loop read, this.IniFile {

                line := Trim(A_LoopReadLine)

                if (line = "")
                    continue

                if (SubStr(line, 1, 1) = "[") {
                    inShortcutsSection := (line = "[Shortcuts]")
                    continue
                }

                if !inShortcutsSection
                    continue

                if InStr(line, "=") {

                    eqPos := InStr(line, "=")

                    encodedShort :=
                        Trim(
                            SubStr(
                                line,
                                1,
                                eqPos - 1
                            )
                        )

                    repl :=
                        Trim(
                            SubStr(
                                line,
                                eqPos + 1
                            )
                        )

                    short :=
                        this.DecodeShortcut(
                            encodedShort
                        )

                    if (short != "" && repl != "") {

                        items.Push({
                            short: short,
                            repl: repl
                        })
                    }
                }
            }

        } catch {
            ; ignore
        }

        return items
    }


    ; ===============================================================
    ; نمایش GUI
    ; ===============================================================
    static ShowGUI() {

        if (this.GuiObj) {
            try this.GuiObj.Destroy()
        }

        myGui :=
            Gui(
                "+AlwaysOnTop +Resize",
                "مدیریت تبدیل"
            )

        myGui.SetFont(
            "s10",
            "Segoe UI"
        )

        myLv :=
            myGui.AddListView(
                "w500 h300 -Multi -ReadOnly",
                ["میان‌بر", "جایگزین"]
            )

        myLv.OnEvent(
            "DoubleClick",
            (*) => this.EditSelected(
                myLv,
                myGui
            )
        )

; دکمه‌ها
btnAdd := myGui.AddButton("w100 x390 y+10", "افزودن")
btnEdit := myGui.AddButton("w100 x280 yp", "ویرایش")
btnDelete := myGui.AddButton("w100 x170 yp", "حذف")

btnAdd.OnEvent("Click", (*) => this.AddNew(myGui, myLv))
btnEdit.OnEvent("Click", (*) => this.EditSelected(myLv, myGui))
btnDelete.OnEvent("Click", (*) => this.DeleteSelected(myLv, myGui))



        this.RefreshList(myLv)

        myGui.OnEvent(
            "Escape",
            (*) => myGui.Destroy()
        )

        myGui.OnEvent(
            "Close",
            (*) => myGui.Destroy()
        )

        myGui.Show()

        this.GuiObj := myGui
        this.ListView := myLv
    }


    ; ===============================================================
    ; Refresh List
    ; ===============================================================
    static RefreshList(lv) {

        lv.Delete()

        items := this.GetAllShortcuts()

        for item in items {

            displayShort :=
                this.EncodeShortcut(
                    item.short
                )

            displayRepl := item.repl

            if (InStr(item.repl, "{date:") = 1) {

                dateFormat :=
                    SubStr(
                        item.repl,
                        7,
                        -1
                    )

                if (InStr(dateFormat, "شمسی:") = 1) {

                    displayRepl :=
                        "📅 شمسی: "
                        . Trim(
                            StrReplace(
                                dateFormat,
                                "شمسی:",
                                ""
                            )
                        )

                } else if (InStr(dateFormat, "میلادی:") = 1) {

                    displayRepl :=
                        "📅 میلادی: "
                        . Trim(
                            StrReplace(
                                dateFormat,
                                "میلادی:",
                                ""
                            )
                        )

                } else {

                    displayRepl :=
                        "📅 "
                        . dateFormat
                }
            }

            lv.Add(
                "",
                displayShort,
                displayRepl
            )
        }

        lv.ModifyCol(
            1,
            "AutoHdr"
        )

        lv.ModifyCol(
            2,
            "AutoHdr"
        )
    }


    ; ===============================================================
    ; افزودن
    ; ===============================================================
    static AddNew(gui, lv) {
        this.EditDialog(
            gui,
            lv,
            "",
            ""
        )
    }


    ; ===============================================================
    ; ویرایش
    ; ===============================================================
    static EditSelected(lv, gui) {

        row := lv.GetNext()

        if !row {

            MsgBox(
                "لطفاً یک آیتم را انتخاب کنید.",
                "توجه",
                "0x30 0x40000"
            )

            return
        }

        short :=
            lv.GetText(
                row,
                1
            )

        short :=
            this.DecodeShortcut(
                short
            )

        rawRepl := ""

        items :=
            this.GetAllShortcuts()

        for item in items {

            if (item.short = short) {

                rawRepl := item.repl
                break
            }
        }

        if (rawRepl = "")
            return

        isDate := false
        dateFormat := ""

        if (InStr(rawRepl, "{date:") = 1) {

            isDate := true

            dateFormat :=
                SubStr(
                    rawRepl,
                    7,
                    -1
                )
        }

        this.EditDialog(
            gui,
            lv,
            short,
            rawRepl,
            isDate,
            dateFormat
        )
    }

; ===============================================================
; حذف
; ===============================================================
static DeleteSelected(lv, gui) {
    row := lv.GetNext()
    if !row {
        MsgBox("لطفاً یک آیتم را انتخاب کنید.", "توجه", "0x30 0x40000")
        return
    }
    
    short := lv.GetText(row, 1)
    short := this.DecodeShortcut(short)
    
    this.DeleteShortcutFromIni(short)
    this.RefreshList(lv)
}
    ; ===============================================================
    ; اضافه
    ; ===============================================================
static EditDialog(parentGui, lv, short, repl, isDate := false, dateFormat := "") {
    isNew := (short = "" && repl = "")
    
    dlg := Gui("+AlwaysOnTop +Owner" . parentGui.Hwnd, isNew ? "افزودن تبدیل" : "ویرایش تبدیل")
    dlg.SetFont("s10", "Segoe UI")
    
    displayShort := this.EncodeShortcut(short)
    
    ; ========================================
    ; ردیف 1: میان‌بر
    ; ========================================
    dlg.AddText("w120 x270 y10 Right", ":میان‌بر")      ; ← عرض 120، موقعیت 270
    edShort := dlg.AddEdit("w180 x80 yp-3 vShort", displayShort)   ; ← عرض 180، موقعیت 80
    edShort.OnEvent("Change", (*) => this.ValidateShortcut(edShort))
    
    ; ========================================
    ; ردیف 2: جایگزین
    ; ========================================
    dlg.AddText("w120 x270 y+15 Right", ":جایگزین")
    edRepl := dlg.AddEdit("w180 x80 yp-3 vRepl", repl)
    edRepl.OnEvent("Change", (ctrl, *) => this.ValidateShortcut(ctrl))
    
    ; ========================================
    ; کامبوباکس تاریخ (همان موقعیت جایگزین)
    ; ========================================
    edRepl.GetPos(&x, &y, &w, &h)
    cbFormats := dlg.AddComboBox("x" x " y" y " w180 vDateFormat Choose1", this.DateFormats)
    cbFormats.OnEvent("Change", (ctrl, *) => this.ValidateShortcut(ctrl))
    
    edRepl.Visible := !isDate
    cbFormats.Visible := isDate
    
    ; ========================================
    ; ردیف 3: چک‌باکس تاریخ
    ; ========================================
    chkDate := dlg.AddCheckbox("w180 x80 y+15 Right vUseDate Checked" . (isDate ? "1" : "0"), "استفاده از تاریخ و زمان")
    chkDate.OnEvent("Click", (*) => this.ToggleDateMode(edRepl, cbFormats, chkDate))
    
    ; ========================================
    ; دکمه‌ها
    ; ========================================
    btnOK := dlg.AddButton("w100 x270 y+20 Default", "ذخیره")
    btnCancel := dlg.AddButton("w100 x160 yp", "انصراف")
    
    btnOK.OnEvent("Click", (*) => this.SaveFromDialog(dlg, edShort, edRepl, cbFormats, chkDate, lv))
    btnCancel.OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Escape", (*) => dlg.Destroy())
    dlg.OnEvent("Close", (*) => dlg.Destroy())
    
    dlg.Show("w400")   ; ← عرض پنجره ۴۰۰ پیکسل
}


    ; ===============================================================
    ; تغییر حالت تاریخ
    ; ===============================================================
    static ToggleDateMode(
        edRepl,
        cbFormats,
        chkDate
    ) {

        isDate := chkDate.Value

        edRepl.Visible := !isDate

        cbFormats.Visible := isDate

        if (isDate)
            cbFormats.Choose(1)
    }


    ; ===============================================================
    ; اعتبارسنجی میان‌بر
    ; ===============================================================
static ValidateShortcut(ed) {
        static processing := false

        if processing
            return

        processing := true

        val := ed.Text

        if InStr(val, " ") {
            newVal := StrReplace(val, " ", "{space}")
            ed.Text := newVal

            targetHwnd := ed.Hwnd
            if (ed.Type = "ComboBox") {
                targetHwnd := DllCall("user32\GetWindow", "Ptr", ed.Hwnd, "UInt", 5, "Ptr")
            }

            try {
                SendMessage(0x00B1, StrLen(newVal), StrLen(newVal), targetHwnd)
                SendMessage(0x00B7, 0, 0, targetHwnd)
            }
        }

        processing := false
    }


    ; ===============================================================
    ; ذخیره از پنجره
    ; ===============================================================
    static SaveFromDialog(
        dlg,
        edShort,
        edRepl,
        cbFormats,
        chkDate,
        lv
    ) {

        shortDisplay := edShort.Value

        short :=
            this.DecodeShortcut(
                shortDisplay
            )

        ; -----------------------------------------------------------
        ; تاریخ
        ; -----------------------------------------------------------
        if (chkDate.Value) {

            dateFormat :=
                Trim(
                    cbFormats.Text
                )

            dateFormat :=
                StrReplace(
                    dateFormat,
                    "📅",
                    ""
                )

            dateFormat := Trim(dateFormat)

            if (
                dateFormat != ""
                && !InStr(dateFormat, "میلادی:")
                && !InStr(dateFormat, "شمسی:")
            ) {

                dateFormat :=
                    "میلادی: "
                    . dateFormat
            }

            if (dateFormat = "") {

                MsgBox(
                    "لطفاً فرمت تاریخ را انتخاب یا وارد کنید.",
                    "خطا",
                    "0x10 0x40000"
                )

                return
            }

            repl :=
                "{date:"
                . dateFormat
                . "}"

        } else {

            ; -------------------------------------------------------
            ; متن معمولی
            ; -------------------------------------------------------
            repl :=
                Trim(
                    edRepl.Value
                )
        }

        ; -----------------------------------------------------------
        ; اعتبارسنجی
        ; -----------------------------------------------------------
        if (short = "") {

            MsgBox(
                ".میان‌بر نمی‌تواند خالی باشد",
                "خطا",
                "0x10 0x40000"
            )

            return
        }

        if (repl = "") {

            MsgBox(
                ".جایگزین نمی‌تواند خالی باشد",
                "خطا",
                "0x10 0x40000"
            )

            return
        }

        ; -----------------------------------------------------------
        ; بررسی میان‌بر تکراری
        ; -----------------------------------------------------------
items := this.GetAllShortcuts()

for item in items {
    if (item.short = short && item.repl != repl) {
        result := MsgBox(
            "میان‌بر تکراری است، آیا می‌خواهید آن را جایگزین کنید؟",
            "تکرار",
            "4 0x40000 Owner" . dlg.Hwnd   ; 4 = Yes/No
        )
        if (result != "Yes")   ; اگر کاربر "بله" را انتخاب نکند (یعنی "خیر" یا "انصراف" را بزند)
            return
        break
    }
}

        ; -----------------------------------------------------------
        ; ذخیره
        ; -----------------------------------------------------------
        this.SaveShortcut(
            short,
            repl
        )

        dlg.Destroy()

        this.RefreshList(lv)
    }
}
; ===============================================================
; Initialization
; ===============================================================
CreateTrayMenu()

SetCustomTrayIcon()

; رفع مسیر رجیستری در صورت جابجایی فایل
FixStartupPathAfterMove()

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

; بارگذاری میان‌بر‌های متنی از فایل INI (همان فایل En2Fa.ini)
ShortcutManager.LoadAndEnable()

Persistent

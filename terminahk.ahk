#Requires AutoHotkey v2.1-alpha
#SingleInstance Off
#MaxThreads 255
#MaxThreadsPerHotkey 1
#UseHook true
ProcessSetPriority('H')
; === Module 1: Global State & Constants ===

APP_NAME := "TerminAHK"
VERSION := "0.1.1"

hGui := 0
hOutput := 0
hInput := 0
hPrompt := 0

CurrentTheme := Map()
SessionLogPath := ""
SessionLogFile := 0

CommandHistory := Array()
HistoryIndex := 0

CustomCommands := Map()
HotkeyRegistry := Map()
HotkeyCommandMap := Map()

IsProcessing := false
WorkingDirectory := A_WorkingDir

ConfigDir := A_ScriptDir "\config"
DataDir := A_ScriptDir "\data"
SessionDir := DataDir "\sessions"

AutosavePath := DataDir "\autosave.ini"
ThemePath := ConfigDir "\theme.cfg"
CustomCommandsPath := ConfigDir "\customcommands.cfg"

; === Module 2: ConfigManager (Autosave) ===

EnsureDirectories() {
    if !DirExist(ConfigDir)
        DirCreate(ConfigDir)
    if !DirExist(DataDir)
        DirCreate(DataDir)
    if !DirExist(SessionDir)
        DirCreate(SessionDir)
}

DefaultAutosave() {
    defaults := Map()
    defaults["WindowX"] := ""
    defaults["WindowY"] := ""
    defaults["WindowW"] := "900"
    defaults["WindowH"] := "600"
    defaults["Theme"] := "Default"
    defaults["HistoryCount"] := "0"
    return defaults
}

LoadAutosave() {
    global AutosavePath
    if !FileExist(AutosavePath) {
        SaveAutosave(DefaultAutosave())
        return DefaultAutosave()
    }
    data := Map()
    data["WindowX"] := IniRead(AutosavePath, "State", "WindowX", "")
    data["WindowY"] := IniRead(AutosavePath, "State", "WindowY", "")
    data["WindowW"] := IniRead(AutosavePath, "State", "WindowW", "900")
    data["WindowH"] := IniRead(AutosavePath, "State", "WindowH", "600")
    data["Theme"] := IniRead(AutosavePath, "State", "Theme", "Default")
    data["HistoryCount"] := IniRead(AutosavePath, "State", "HistoryCount", "0")
    count := Integer(data["HistoryCount"])
    global CommandHistory
    CommandHistory := Array()
    Loop count {
        cmd := IniRead(AutosavePath, "History", "Item" A_Index, "")
        if cmd != ""
            CommandHistory.Push(cmd)
    }
    global HistoryIndex
    HistoryIndex := CommandHistory.Length + 1
    return data
}

SaveAutosave(data := "") {
    global AutosavePath, hGui, CommandHistory, CurrentTheme
    if !IsObject(data)
        data := Map()
    if hGui {
        try {
            WinGetPos(&winX, &winY, &winW, &winH, hGui)
            data["WindowX"] := winX
            data["WindowY"] := winY
            data["WindowW"] := winW
            data["WindowH"] := winH
        } catch Error as e {
            data["WindowX"] := data.Has("WindowX") ? data["WindowX"] : ""
            data["WindowY"] := data.Has("WindowY") ? data["WindowY"] : ""
            data["WindowW"] := data.Has("WindowW") ? data["WindowW"] : "900"
            data["WindowH"] := data.Has("WindowH") ? data["WindowH"] : "600"
        }
    }
    if !data.Has("WindowX")
        data["WindowX"] := ""
    if !data.Has("WindowY")
        data["WindowY"] := ""
    if !data.Has("WindowW")
        data["WindowW"] := "900"
    if !data.Has("WindowH")
        data["WindowH"] := "600"
    if !data.Has("Theme")
        data["Theme"] := CurrentTheme.Has("Name") ? CurrentTheme["Name"] : "Default"
    data["HistoryCount"] := CommandHistory.Length
    IniWrite(data["WindowX"], AutosavePath, "State", "WindowX")
    IniWrite(data["WindowY"], AutosavePath, "State", "WindowY")
    IniWrite(data["WindowW"], AutosavePath, "State", "WindowW")
    IniWrite(data["WindowH"], AutosavePath, "State", "WindowH")
    IniWrite(data["Theme"], AutosavePath, "State", "Theme")
    IniWrite(data["HistoryCount"], AutosavePath, "State", "HistoryCount")
    Loop CommandHistory.Length {
        IniWrite(CommandHistory[A_Index], AutosavePath, "History", "Item" A_Index)
    }
}

; === Module 3: ThemeManager ===

LoadTheme(name) {
    global ThemePath, CurrentTheme
    if !FileExist(ThemePath)
        return ValidateTheme(Map("Name", "Default"))
    CurrentTheme := Map()
    CurrentTheme["Name"] := name
    try {
        CurrentTheme["Background"] := IniRead(ThemePath, name, "Background", "0x1E1E1E")
        CurrentTheme["Foreground"] := IniRead(ThemePath, name, "Foreground", "0xCCCCCC")
        CurrentTheme["Accent"] := IniRead(ThemePath, name, "Accent", "0x007ACC")
        CurrentTheme["ErrorColor"] := IniRead(ThemePath, name, "ErrorColor", "0xFF4444")
        CurrentTheme["FontFace"] := IniRead(ThemePath, name, "FontFace", "Consolas")
        CurrentTheme["FontSize"] := IniRead(ThemePath, name, "FontSize", "11")
        CurrentTheme["Padding"] := IniRead(ThemePath, name, "Padding", "4")
        CurrentTheme["Transparency"] := IniRead(ThemePath, name, "Transparency", "255")
    } catch {
        return ValidateTheme(Map("Name", "Default"))
    }
    return ValidateTheme(CurrentTheme)
}

ApplyTheme() {
    global hGui, hOutput, hInput, hPrompt, CurrentTheme
    if !CurrentTheme.Has("Background")
        return
    bg := Integer(CurrentTheme["Background"])
    fg := Integer(CurrentTheme["Foreground"])
    accent := Integer(CurrentTheme["Accent"])
    fontFace := CurrentTheme["FontFace"]
    fontSize := Integer(CurrentTheme["FontSize"])
    trans := Integer(CurrentTheme["Transparency"])
    if hGui {
        hGui.BackColor := Format("{:06X}", bg & 0xFFFFFF)
        WinSetTransparent(trans, hGui)
    }
    if hOutput {
        hOutput.SetFont("s" fontSize " c" Format("{:06X}", fg & 0xFFFFFF), fontFace)
        hOutput.Opt("Background" Format("{:06X}", bg & 0xFFFFFF))
    }
    if hInput {
        hInput.SetFont("s" fontSize " c" Format("{:06X}", fg & 0xFFFFFF), fontFace)
        hInput.Opt("Background" Format("{:06X}", bg & 0xFFFFFF))
    }
    if hPrompt {
        hPrompt.SetFont("s" fontSize " c" Format("{:06X}", accent & 0xFFFFFF), fontFace)
    }
}

ListThemes() {
    global ThemePath
    themes := Array()
    if !FileExist(ThemePath)
        return themes
    text := FileRead(ThemePath)
    Loop Parse, text, "`n", "`r" {
        line := Trim(A_LoopField)
        if SubStr(line, 1, 1) = "[" && SubStr(line, -1) = "]" {
            name := SubStr(line, 2, StrLen(line) - 2)
            themes.Push(name)
        }
    }
    return themes
}

ValidateTheme(theme) {
    defaults := Map()
    defaults["Name"] := "Default"
    defaults["Background"] := "0x1E1E1E"
    defaults["Foreground"] := "0xCCCCCC"
    defaults["Accent"] := "0x007ACC"
    defaults["ErrorColor"] := "0xFF4444"
    defaults["FontFace"] := "Consolas"
    defaults["FontSize"] := "11"
    defaults["Padding"] := "4"
    defaults["Transparency"] := "255"
    for key, val in defaults {
        if !theme.Has(key)
            theme[key] := val
    }
    return theme
}

; === Module 4: SessionLogger ===

StartSession() {
    global SessionDir, SessionLogPath, SessionLogFile
    timestamp := FormatTime(A_Now, "yyyyMMdd_HHmmss")
    SessionLogPath := SessionDir "\session_" timestamp ".log"
    SessionLogFile := FileOpen(SessionLogPath, "w", "UTF-8")
    if !IsObject(SessionLogFile)
        SessionLogFile := 0
}

LogInput(cmd) {
    global SessionLogFile
    if IsObject(SessionLogFile) {
        ts := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        SessionLogFile.WriteLine("[" ts "] > " cmd)
        SessionLogFile.Read(0)
    }
}

LogOutput(text, isError := false) {
    global SessionLogFile
    if IsObject(SessionLogFile) {
        ts := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        prefix := isError ? "[ERR]" : "[OUT]"
        SessionLogFile.WriteLine("[" ts "] " prefix " " text)
        SessionLogFile.Read(0)
    }
}

EndSession() {
    global SessionLogFile
    if IsObject(SessionLogFile) {
        SessionLogFile.Close()
        SessionLogFile := 0
    }
}

ListSessions() {
    global SessionDir
    sessions := Array()
    if !DirExist(SessionDir)
        return sessions
    Loop Files, SessionDir "\*.log" {
        sessions.Push(A_LoopFileName)
    }
    return sessions
}

; === Module 5: CommandParser ===

ParseInput(raw) {
    global IsProcessing
    if IsProcessing
        return
    input := Trim(raw)
    if input = ""
        return
    global CommandHistory, HistoryIndex
    CommandHistory.Push(input)
    HistoryIndex := CommandHistory.Length + 1
    LogInput(input)
    AppendOutput("> " raw)
    tokens := Tokenize(input)
    if tokens.Length = 0
        return
    cmdType := GetCommandType(tokens)
    if cmdType = "custom"
        ExecuteCustomCommand(tokens)
    else
        ExecuteShell(input)
}

Tokenize(input) {
    tokens := Array()
    current := ""
    inQuote := false
    quoteChar := ""
    Loop Parse, input {
        char := A_LoopField
        if (char = '"' || char = "'") && !inQuote {
            inQuote := true
            quoteChar := char
        } else if (char = quoteChar) && inQuote {
            inQuote := false
            quoteChar := ""
        } else if (char = " ") && !inQuote {
            if current != "" {
                tokens.Push(current)
                current := ""
            }
        } else {
            current .= char
        }
    }
    if current != ""
        tokens.Push(current)
    return tokens
}

GetCommandType(tokens) {
    global CustomCommands
    if tokens.Length = 0
        return "shell"
    name := tokens[1]
    if CustomCommands.Has(name)
        return "custom"
    if name = "makeHotKey" || name = "setTheme" || name = "listThemes" || name = "clear" || name = "history" || name = "saveConfig" || name = "help" || name = "exit" || name = "clearHistory" || name = "clearLogs"
        return "custom"
    return "shell"
}

; === Module 6: CustomCommandFramework ===

global ModifierKeys := Map("!", "Alt", "#", "Win", "^", "Ctrl", "+", "Shift")

global ComplexKeys := Array("Tab", "Enter", "Escape", "Space", "Backspace", "Delete", "Insert", "Home", "End", "PgUp", "PgDn", "Up", "Down", "Left", "Right", "NumpadEnter", "NumpadAdd", "NumpadSub", "NumpadMult", "NumpadDiv")

global FuncKeys := Array()
Loop 12 {
    FuncKeys.Push("F" A_Index)
}

global MouseKeys := Array("LButton", "RButton", "MButton", "XButton1", "XButton2")

NormalizeKey(key) {
    if (key = "" || key = false)
        return ""
    key := Trim(key)
    key := StrUpper(key)
    key := RegExReplace(key, "\s", "")
    key := StrReplace(key, "WIN+", "#")
    key := StrReplace(key, "CTRL+", "^")
    key := StrReplace(key, "ALT+", "!")
    key := StrReplace(key, "SHIFT+", "+")
    key := StrReplace(key, "WIN", "#")
    key := StrReplace(key, "CTRL", "^")
    key := StrReplace(key, "ALT", "!")
    key := StrReplace(key, "SHIFT", "+")
    pos := RegExMatch(key, "[\w]")
    if (pos = 0)
        return ""
    modifiers := SubStr(key, 1, pos - 1)
    baseKey := SubStr(key, pos)
    if (StrLen(baseKey) != 1) {
        uBase := StrUpper(baseKey)
        isComplex := false
        for c in ComplexKeys {
            if (c = uBase) {
                isComplex := true
                break
            }
        }
        if !isComplex {
            for f in FuncKeys {
                if (f = uBase) {
                    isComplex := true
                    break
                }
            }
        }
        if !isComplex {
            for m in MouseKeys {
                if (m = uBase) {
                    isComplex := true
                    break
                }
            }
        }
        if !isComplex
            return ""
    }
    seen := ""
    Loop StrLen(modifiers) {
        mod := SubStr(modifiers, A_Index, 1)
        if InStr(seen, mod)
            return ""
        seen .= mod
    }
    if !RegExMatch(baseKey, "^[\w]+$")
        return ""
    if !RegExMatch(key, "^[\^!+#]*[\w]+$")
        return ""
    return key
}

LoadCustomCommands() {
    global CustomCommandsPath, CustomCommands, HotkeyRegistry, HotkeyCommandMap
    CustomCommands := Map()
    HotkeyRegistry := Map()
    HotkeyCommandMap := Map()
    if !FileExist(CustomCommandsPath)
        return
    section := ""
    text := FileRead(CustomCommandsPath)
    Loop Parse, text, "`n", "`r" {
        line := Trim(A_LoopField)
        if line = ""
            continue
        if SubStr(line, 1, 1) = "[" && SubStr(line, -1) = "]" {
            section := SubStr(line, 2, StrLen(line) - 2)
            continue
        }
        if section = "Aliases" {
            pos := InStr(line, "=")
            if pos {
                name := Trim(SubStr(line, 1, pos - 1))
                val := Trim(SubStr(line, pos + 1))
                CustomCommands[name] := Map("type", "alias", "value", val)
            }
        } else if section = "Hotkeys" {
            pos := InStr(line, "=")
            if pos {
                hotkey := Trim(SubStr(line, 1, pos - 1))
                cmd := Trim(SubStr(line, pos + 1))
                normalized := NormalizeKey(hotkey)
                if normalized != "" {
                    HotkeyRegistry[hotkey] := cmd
                    RegisterHotkey(normalized, cmd)
                }
            }
        }
    }
}

SaveCustomCommands() {
    global CustomCommandsPath, CustomCommands, HotkeyRegistry
    file := FileOpen(CustomCommandsPath, "w", "UTF-8")
    if !IsObject(file)
        return
    file.WriteLine("[Aliases]")
    for name, def in CustomCommands {
        if def["type"] = "alias"
            file.WriteLine(name "=" def["value"])
    }
    file.WriteLine("")
    file.WriteLine("[Hotkeys]")
    for hotkey, cmd in HotkeyRegistry {
        file.WriteLine(hotkey "=" cmd)
    }
    file.Close()
}

ExecuteCustomCommand(tokens) {
    if tokens.Length = 0
        return
    name := tokens[1]
    global CustomCommands
    if CustomCommands.Has(name) && CustomCommands[name]["type"] = "alias" {
        ExecuteShell(CustomCommands[name]["value"])
        return
    }
    switch name {
        case "makeHotKey": HandleMakeHotKey(tokens)
        case "setTheme": HandleSetTheme(tokens)
        case "listThemes": HandleListThemes()
        case "clear": HandleClear()
        case "history": HandleHistory()
        case "saveConfig": HandleSaveConfig()
        case "help": HandleHelp()
        case "exit": HandleExit()
        case "clearHistory": HandleClearHistory()
        case "clearLogs": HandleClearLogs()
        default: AppendOutput("Unknown command: " name, true)
    }
}

RegisterHotkey(hotkeyi, command) {
    global HotkeyCommandMap
    try {
        HotkeyCommandMap[hotkeyi] := command
        Hotkey(hotkeyi, HotkeyDispatcher)
        return ""
    } catch Error as e {
        return e.Message
    }
}

HotkeyDispatcher(hk) {
    global HotkeyCommandMap
    if HotkeyCommandMap.Has(hk)
        ParseInput(HotkeyCommandMap[hk])
}

HandleMakeHotKey(tokens) {
    if tokens.Length < 5 {
        AppendOutput("Usage: makeHotKey -I {hotkey} -O {command}", true)
        return
    }
    hk := ""
    cmd := ""
    cmdIndex := 0
    Loop tokens.Length {
        if tokens[A_Index] = "-I" && A_Index < tokens.Length
            hk := tokens[A_Index + 1]
        if tokens[A_Index] = "-O" && A_Index < tokens.Length {
            cmdIndex := A_Index + 1
            break
        }
    }
    if cmdIndex > 0 && cmdIndex <= tokens.Length {
        cmd := tokens[cmdIndex]
        Loop tokens.Length - cmdIndex {
            cmd .= " " tokens[cmdIndex + A_Index]
        }
    }
    if hk = "" {
        AppendOutput("Error: No hotkey specified. Use -I {hotkey}", true)
        return
    }
    if cmd = "" {
        AppendOutput("Error: No command specified. Use -O {command}", true)
        return
    }
    normalized := NormalizeKey(hk)
    if normalized = "" {
        AppendOutput("Error: Invalid hotkey '" hk "'. Supported modifiers: WIN, CTRL, ALT, SHIFT. Examples: CTRL+T, ALT+F4, WIN+Q", true)
        return
    }
    global HotkeyRegistry
    wasOverwrite := HotkeyRegistry.Has(hk)
    oldCmd := wasOverwrite ? HotkeyRegistry[hk] : ""
    errMsg := RegisterHotkey(normalized, cmd)
    if errMsg = "" {
        HotkeyRegistry[hk] := cmd
        SaveCustomCommands()
        if wasOverwrite
            AppendOutput("Hotkey overwritten: " hk " => " cmd " (was: " oldCmd ")")
        else
            AppendOutput("Hotkey registered: " hk " => " cmd)
    } else {
        AppendOutput("Error: Failed to register hotkey '" hk "' (" normalized ")", true)
        AppendOutput("Reason: " errMsg, true)
        if InStr(errMsg, "already registered")
            AppendOutput("Hint: Another script or system process may be using this hotkey.", true)
        else if InStr(errMsg, "not allowed")
            AppendOutput("Hint: This key combination is reserved by the system.", true)
        else if InStr(errMsg, "Invalid")
            AppendOutput("Hint: Check the hotkey syntax against AHK documentation.", true)
    }
}

HandleSetTheme(tokens) {
    if tokens.Length < 2 {
        AppendOutput("Usage: setTheme {name}", true)
        return
    }
    name := tokens[2]
    LoadTheme(name)
    ApplyTheme()
    SaveAutosave()
    AppendOutput("Theme set to: " name)
}

HandleListThemes() {
    themes := ListThemes()
    if themes.Length = 0 {
        AppendOutput("No themes found.")
        return
    }
    AppendOutput("Available themes:")
    for theme in themes
        AppendOutput("  " theme)
}

HandleClear() {
    global hOutput
    if hOutput
        hOutput.Value := ""
}

HandleHistory() {
    global CommandHistory
    if CommandHistory.Length = 0 {
        AppendOutput("No history found.", true)
        return
    }
    Loop CommandHistory.Length
        AppendOutput(A_Index ". " CommandHistory[A_Index])
}

HandleClearHistory() {
    global CommandHistory, HistoryIndex, AutosavePath
    CommandHistory := Array()
    HistoryIndex := 1
    IniDelete(AutosavePath, "History")
    IniWrite(0, AutosavePath, "State", "HistoryCount")
    AppendOutput("Command history cleared.")
}

HandleClearLogs() {
    global SessionDir
    if !DirExist(SessionDir) {
        AppendOutput("No logs directory found.")
        return
    }
    count := 0
    Loop Files, SessionDir "\*.log" {
        FileDelete(A_LoopFileFullPath)
        count++
    }
    AppendOutput("Session logs cleared (" count " files).")
}

HandleSaveConfig() {
    SaveAutosave()
    SaveCustomCommands()
    AppendOutput("Configuration saved.")
}

HandleHelp() {
    AppendOutput("Built-in commands:")
    AppendOutput("  help                          Show this message")
    AppendOutput("  listThemes                    List available themes")
    AppendOutput("  setTheme {name}               Change theme")
    AppendOutput("  history                       Show command history")
    AppendOutput("  clear                         Clear output")
    AppendOutput("  clearHistory                  Clear command history")
    AppendOutput("  clearLogs                     Clear session logs")
    AppendOutput("  makeHotKey -I {hk} -O {cmd}   Register a hotkey")
    AppendOutput("  saveConfig                    Save settings")
    AppendOutput("  reload                        Reloads the application")
    AppendOutput("  exit                          Exit the application")
    AppendOutput("Any other input is passed to cmd.exe")
}

HandleExit() {
    AppendOutput("Exiting...")
    ExitApp()
}

HandleReload() {
    AppendOutput("Reloading...")
    Reload()
}

; === Module 7: ShellBridge ===

ExecuteShell(command) {
    global IsProcessing, WorkingDirectory
    IsProcessing := true
    tempFile := A_Temp "\term_" A_TickCount ".tmp"
    try {
        RunWait('cmd.exe /c ' command ' > "' tempFile '" 2>&1', WorkingDirectory, "Hide")
        if FileExist(tempFile) {
            file := FileOpen(tempFile, "r", "UTF-8")
            if IsObject(file) {
                while !file.AtEOF {
                    line := file.ReadLine()
                    AppendOutput(line)
                    LogOutput(line)
                }
                file.Close()
            }
            FileDelete(tempFile)
        }
    } catch Error as e {
        AppendOutput("Shell error: " e.Message, true)
        LogOutput(e.Message, true)
    }
    IsProcessing := false
}

SetWorkingDirectory(path) {
    global WorkingDirectory
    if DirExist(path)
        WorkingDirectory := path
}

; === Module 8: GUI Builder & Event Handlers ===

BuildGui() {
    global hGui, hOutput, hInput, hPrompt
    hGui := Gui("+Resize +MinSize500x300", APP_NAME " v" VERSION)
    hGui.OnEvent("Size", OnGuiResize)
    hGui.OnEvent("Close", OnExit)
    hGui.OnEvent("Escape", OnExit)
    hPrompt := hGui.Add("Text", "x8 y584 w16 h23", ">")
    hInput := hGui.Add("Edit", "x32 y584 w860 h23")
    hInput.OnEvent("Focus", (*) => hInput.Focus())
    hOutput := hGui.Add("Edit", "x8 y8 w884 h568 ReadOnly Multi VScroll HScroll")
    hGui.Show("w900 h600")
}

OnInputSubmit() {
    global hInput
    if !hInput
        return
    text := hInput.Value
    hInput.Value := ""
    ParseInput(text)
}

HistoryNavigate(dir) {
    global CommandHistory, HistoryIndex, hInput
    if CommandHistory.Length = 0
        return
    HistoryIndex += dir
    if HistoryIndex < 1
        HistoryIndex := 1
    if HistoryIndex > CommandHistory.Length {
        hInput.Value := ""
        HistoryIndex := CommandHistory.Length + 1
    } else
        hInput.Value := CommandHistory[HistoryIndex]
}

OnGuiResize(gui, minMax, width, height) {
    global hOutput, hInput, hPrompt
    if minMax = -1
        return
    pad := Integer(CurrentTheme.Has("Padding") ? CurrentTheme["Padding"] : 4)
    inputH := 23
    outputH := height - inputH - pad * 3 - 8
    if hOutput
        hOutput.Move(pad, pad, width - pad * 2, outputH)
    if hPrompt
        hPrompt.Move(pad, outputH + pad * 2, 16, inputH)
    if hInput
        hInput.Move(pad + 20, outputH + pad * 2, width - pad * 2 - 24, inputH)
}

OnExit(*) {
    SaveAutosave()
    EndSession()
    ExitApp()
}

AppendOutput(text, isError := false) {
    global hOutput, CurrentTheme
    if !hOutput
        return
    prefix := isError ? "[ERR] " : ""
    hOutput.Value .= prefix text "`r`n"
    SendMessage(0x115, 7, 0,, hOutput)
}

#HotIf WinActive(hGui)
Enter::OnInputSubmit()
Up::HistoryNavigate(-1)
Down::HistoryNavigate(1)
#HotIf

; === Module 9: Initialization Sequence ===

EnsureDirectories()
autosave := LoadAutosave()
LoadTheme(autosave["Theme"])
BuildGui()
ApplyTheme()
OnGuiResize(hGui, 0, Integer(autosave["WindowW"]), Integer(autosave["WindowH"]))
LoadCustomCommands()
StartSession()
AppendOutput(APP_NAME " v" VERSION " ready.")
AppendOutput("Type 'help' for available commands.")

; Focus input on startup
hInput.Focus()
# TerminAHK
A Windows Powershell terminal emulator built in AutoHotkey v2
## How it works
TerminAHK simply parses the command line input and passes commands to the shell using a hidden `cmd.exe` window.
## Built-in commands
TerminAHK comes with an array of built-in commands:
- `help` - displays a help menu
- `setTheme` - changes the current theme to any of the themes created in the `theme.cfg` file
- `listThemes` - displays a list of all valid themes accessible
- `clear` - clears the terminal
- `history` - displays the current session's command history
- `clearHistory` - clears the session command history
- `clearLogs` - deletes the log files from the log directory
- `makeHotkey` - | **currently broken** | assigns a hotkey to a shell command
- `exit` - closes the application
   
All other commands are passed directly to the shell  
## Themes

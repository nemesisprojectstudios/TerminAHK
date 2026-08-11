# TerminAHK
A Windows Powershell terminal emulator built in AutoHotkey v2
## How it works
TerminAHK simply parses the command line input and passes commands to the shell using a hidden `cmd.exe` window.
## Built-in commands
TerminAHK comes with an array of built-in commands:
- `help` - displays a help menu
- `setTheme {name}` - changes the current theme to any of the themes created in the `theme.cfg` file
- `listThemes` - displays a list of all valid themes accessible
- `clear` - clears the terminal
- `history` - displays the current session's command history
- `clearHistory` - clears the session command history
- `clearLogs` - deletes the log files from the log directory
- `makeHotkey -I {hotkey} -O {shell command}` - | **currently broken** | assigns a hotkey to a shell command
- `saveConfig` - saves the current settings into the save file
- `reload` - reloads the application
- `exit` - closes the application
   
All other commands are passed directly to the shell  
## Directory tree
The application's directory tree follows the one of this repository. If the repository isn't cloned or not cloned properly, the application will automatically create it's directories and files.

## Themes
There exist predefined themes in `\config\theme.cfg`. You can create your own theme by editing one of the existing ones or by making a new one matching the syntax of the existing ones.  
The default theme looks like this:
```
[Default]  
Background=0x1E1E1E  
Foreground=0xCCCCCC  
Accent=0x007ACC  
ErrorColor=0xFF4444  
FontFace=Consolas  
FontSize=11  
Padding=4  
Transparency=255  
```  
Error colors aren't handled currently, as implementing that change would need a full redesign of the input-output fields.
## Custom commands
You can declare your custom commands or aliases in the `\config\customcommands.cfg` file.  
An example alias is added by default:
```
[Aliases]  
ls=dir /b  
  
[Hotkeys]  
  
```

The syntax is simply `aliascmd=shellcmd /parameter --parameter`, respecting the syntax of the existing Powershell commands
## Autosaving
The `\data\autosave.ini` file stores a few variables to restore the previous state of the terminal emulator when opened. These are automatically saved during runtime.
```
[State]
WindowX=502
WindowY=220
WindowW=916
WindowH=639
Theme=Default
HistoryCount=0
  
[History]
  
```
This includes window coordinates and sizing, theme and command history.
## Session logging
The emulator drops log files into `\data\sessions\session_yymmdd_hhmmss.log`, where yymmdd is the current date and hhmmss is the init timestamp.  
Both command line inputs and outputs are logged. An example of this can be viewed at `\data\sessions\example_session_xyz.log` inside this repository.

# mpv-auto-complete-mover

Automatically move fully watched **local video files** into a `completed` folder when playback finishes in **mpv / mpvnet**.

This script is designed to be reliable on Windows and safe to use with playlists, avoiding common mpv timing and file-locking issues.

---

## Features

- Moves videos only after they are fully watched
- Creates a `completed` folder automatically if it does not exist
- Works correctly with playlists and auto-advance
- Works with single (solo) video files
- Opt-in per session (disabled by default)
- Safe filename handling (no overwrites)
- Skips files already inside a `completed` folder
- Detailed debug logging for troubleshooting

---

## What this script does

When enabled:

1. You watch a local video until the end
2. The file is queued internally
3. Once mpv is in a safe state:
   - The video is moved into a `completed` subfolder
   - The folder is created if missing

The script never moves files early and never guesses.

---

## What this script does NOT do

- Does not move streams or URLs
- Does not run automatically without user action
- Does not persist its enabled state across mpv restarts
- Does not create nested `completed/completed` folders
- Does not overwrite existing files

---

## Installation

1. Copy `move_to_completed.lua` into:

   mpvnet/portable_config/scripts/

2. Restart mpvnet

No other setup is required.

---

## Usage

### Toggle key

- **Ctrl + B** — Toggle move-to-completed ON or OFF

Behavior:
- OFF by default every time mpv starts
- ON persists across file changes and playlists
- Automatically resets to OFF when mpv exits

An on-screen message confirms the toggle state.

---

## Typical workflow

1. Start mpvnet
2. Play a video or playlist
3. Press **Ctrl + B** once (enable)
4. Watch videos normally
5. Finished videos are moved to:

   parent_folder/completed/

---

## Log and state files

The script stores its internal state in mpv’s portable state directory:

mpvnet/portable_config/state/

Files used:

- move_to_completed.log  
  Temporary queue of completed files (created only when needed)

- move_to_completed.enabled  
  Session toggle flag (deleted on mpv exit)

- move_to_completed_debug.log  
  Persistent debug log for troubleshooting

The queue log is automatically deleted when empty.

---

## Debugging

If something does not work as expected, check:

mpvnet/portable_config/state/move_to_completed_debug.log

This file logs:
- Script startup
- Toggle events
- File capture
- End-of-file detection
- Move success or failure

---

## Compatibility

- mpvnet (Windows, portable mode)
- mpv with Lua scripting enabled

This script uses Windows shell commands and is not intended for Linux or macOS.

---

## License

MIT License

You are free to use, modify, and distribute this script.

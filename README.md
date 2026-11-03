# AniWallpaper

A native macOS menu bar app that plays video and GIF wallpapers on your desktop, with a library
window and a picker for choosing a still frame to use on the lock screen.

- Plays `.mp4`, `.mov`, `.m4v` and `.gif` behind your desktop icons on every display, on all Spaces
- Hardware-decoded, looping, muted video (about 2-3% CPU in testing)
- One window with two tabs: **Library** (add, remove, set active) and **Active Wallpaper** (thumbnail, path, and lock screen still picker)
- Setting a wallpaper active uses its first frame as the lock screen still by default
- Pauses when the screen sleeps or locks, when a fullscreen app covers the desktop, and optionally on
  battery or in Low Power Mode (separate toggles)
- Remembers your wallpaper and library; optional Launch at Login

## Requirements
- macOS 13 or later
- Swift toolchain (Xcode **or** just the Command Line Tools: `xcode-select --install`)

## Build and install
```sh
./build.sh      # builds AniWallpaper.app in this folder
./install.sh    # builds, replaces /Applications/AniWallpaper.app, and relaunches it
```
Run `./install.sh` again after any code change. The app is ad-hoc signed, so on first launch macOS may
ask you to right-click it and choose Open.

## Usage
Click the menu bar icon (stacked photos):

| Item | What it does |
| --- | --- |
| Open Library… (⌘L) | Opens the app window (Library and Active Wallpaper tabs) |
| Pause / Resume | Stop or restart playback |
| Pause on Battery | Pause while running on battery power |
| Pause on Low Power Mode | Pause while macOS Low Power Mode is on |
| Launch at Login | Start automatically (works best from `/Applications`) |

You can also open a file directly: `open -a /Applications/AniWallpaper.app clip.mp4`.

### The app window
- **Library tab:** **Add…** imports videos/GIFs, **Remove** deletes an entry from the library (files on
  disk are untouched), **Set as Active Wallpaper** (or double-click) plays it. The active wallpaper is
  marked with ● and can't be removed; set another one active first.
- **Active Wallpaper tab:** shows the active wallpaper's thumbnail and file path. **Select Still…**
  opens a window where you scrub through the video and click **Set as Lock Screen Still**, **Reset to
  Default Still** (first frame), or **Done** to close it.

### Lock screen
macOS does not let third-party apps draw on the lock screen, which always shows the system wallpaper.
Setting a wallpaper active applies its first frame automatically. The Active Wallpaper tab saves your chosen frame as a PNG
(`~/Library/Application Support/AniWallpaper/Stills`) and sets it as the system wallpaper. This
replaces your current system wallpaper, and macOS may keep a separate wallpaper per Space. Animated
lock screens are only possible with Apple's own aerial wallpapers.

## Project layout
```
Package.swift                SwiftPM manifest
Resources/Info.plist         app bundle metadata (menu-bar-only app)
Sources/AniWallpaper/        app source (AppKit, AVFoundation)
build.sh / install.sh        build and install scripts
CLAUDE.md                    context for Claude Code sessions
```
See `CLAUDE.md` for architecture notes and gotchas.

## Not supported (yet)
Web/HTML wallpapers, Metal shader scenes, audio, per-display wallpapers, Wallpaper Engine scene files.

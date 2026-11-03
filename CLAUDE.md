# AniWallpaper: project context for Claude

Native macOS menu bar app that plays video/GIF animated wallpapers on the desktop, with a library
window and a lock-screen still picker. Swift + AppKit, built with SwiftPM (no Xcode project; only the
Command Line Tools are installed on this machine).

> **Standing instruction from the user:** keep this file up to date. Whenever you change behaviour,
> add/remove files, change build or install steps, or learn a new gotcha, update the relevant section
> in the same change. Also update README.md if user-facing behaviour changes.

## Build / run / install
- `./build.sh`: `swift build -c release`, assembles `AniWallpaper.app` in the repo root from
  `Resources/Info.plist`, ad-hoc signs it (`codesign --sign -`).
- `./install.sh`: build, quit the running app, replace `/Applications/AniWallpaper.app`, relaunch.
  This is how the user deploys changes (the `/Applications` copy is separate from the repo copy).
- Launch with a file: `open -a /abs/path/AniWallpaper.app /path/to/video.mp4`. `open -a` needs an
  **absolute** app path.
- Target: macOS 13+, Swift tools 5.9 (Swift 5 language mode). Bundle ID `dev.aditya.aniwallpaper`.
  `LSUIElement=true` (no Dock icon).

## Architecture (Sources/AniWallpaper/)
- `main.swift`: NSApplication bootstrap, `.accessory` activation policy.
- `AppDelegate.swift`: status item + menu, all playback policy, screen/sleep/lock observers, owns
  the library and still-picker window controllers. Menu is deliberately minimal: now-playing label, Open
  Library, Pause/Resume, Pause on Battery, Pause on Low Power Mode, Launch at Login, Quit. Choosing
  wallpapers and lock screen stills lives only in the app window (do not re-add to the menu).
- `DesktopWindowController.swift`: one borderless `NSWindow` per `NSScreen` at
  `desktopWindow level + 1` (above system wallpaper, below desktop icons), `.canJoinAllSpaces`,
  `.stationary`, ignores mouse events. Rebuilt on screen-parameter changes.
- `Renderers.swift`: `WallpaperRenderer` protocol; `VideoRenderer` (AVQueuePlayer + AVPlayerLooper,
  muted, one AVPlayerLayer per screen sharing one player) and `GifRenderer` (NSImageView.animates).
  `RendererFactory` picks by file extension.
- `Library.swift`: `Library` (persisted list of file paths in UserDefaults, posts `didChange`),
  `FrameGrabber` (exact-frame extraction via AVAssetImageGenerator), `Thumbnails` (cached).
- `MainWindowController.swift`: the single app window (`NSTabView`) with two tabs.
  **Library**: thumbnail grid; Add / Remove / Set as Active Wallpaper (double-click also activates).
  The active wallpaper is marked "●" and **cannot be removed** (button disabled + guard in
  `removeTapped`). **Active Wallpaper**: `ActiveWallpaperPane`.
- `ActiveWallpaperPane.swift`: the Active Wallpaper tab shows **only** the wallpaper thumbnail, its
  file path, and a "Select Still…" button (keep it minimal; empty state when nothing is active).
  Closes the still window if the active wallpaper changes.
- `StillPickerWindowController.swift`: separate window opened by "Select Still…": frame slider +
  preview, "Set as Lock Screen Still", "Reset to Default Still" (first frame), and "Done" (closes).
- `LockScreenStill.swift`: extracts a full-res frame, writes a PNG to
  `~/Library/Application Support/AniWallpaper/Stills/`, and calls `NSWorkspace.setDesktopImageURL`
  for every screen.
- `Settings.swift`: last wallpaper (bookmark data in UserDefaults) the independent pause-on-battery / pause-on-low-power flags, and `stillTime` (chosen lock screen
  still position in seconds; nil = default first frame).

## Behaviour notes
- Playback pauses when: user paused, screens asleep, screen locked (distributed notifications
  `com.apple.screenIsLocked/Unlocked`), no wallpaper window visible (occlusion, e.g. fullscreen app),
  or on battery (`Settings.pauseOnBattery`) / Low Power Mode (`Settings.pauseOnLowPower`), each with its
  own independent menu toggle. A 30 s timer re-evaluates battery state.
- `AppDelegate.activate(_:)` is the user-initiated path (library Set Active, or opening a file): it
  saves the wallpaper, clears `stillTime`, plays it, and **sets the first frame as the system
  wallpaper (lock screen) by default**. `load(_:)` just plays without touching the system wallpaper;
  it is used when restoring the saved wallpaper at launch, so relaunching never overwrites the
  user's system wallpaper. Anything loaded is added to the library automatically.
- The window switches the activation policy to `.regular` while open and back to `.accessory` on close.

## Gotchas (learned the hard way)
- **`application(_:openFile:)` can fire before `applicationDidFinishLaunching`.** UI and observers are
  therefore set up in `applicationWillFinishLaunching`; the saved wallpaper is only restored in
  didFinishLaunching if nothing was opened already. Otherwise: nil-unwrap crash on launch-with-file.
- **Lock screen limitation:** third-party apps cannot draw on the lock screen (loginwindow owns it).
  The lock screen uses the *system wallpaper*, so the still picker sets a still as system wallpaper.
  Animated lock screens would require injecting into Apple's aerial catalog under
  `/Library/Application Support/com.apple.idleassetsd/`: not implemented (needs admin, fragile
  across macOS releases). Don't touch system files without asking the user.
- Still PNGs get a unique timestamped filename each time so macOS doesn't serve a cached image.
  Setting a still replaces the user's system wallpaper (including any Apple aerial they had).
- "Launch at Login" (`SMAppService.mainApp`) registers the app at its *current location*. The user
  runs it from `/Applications`; re-toggle it if the app is moved or login launch stops working.
- `.gitignore` excludes `.build/`, `*.app/`, `.swiftpm/`, `.DS_Store`. An early commit accidentally
  included build artifacts and was amended; never commit `.build/` or the `.app`.

## Testing / verification limits
- No automated tests. Verify by building, launching, and checking the process stays up
  (`pgrep -lf AniWallpaper`, CPU via `ps -o %cpu`), crash reports in
  `~/Library/Logs/DiagnosticReports/AniWallpaper-*.ips`, and window level/bounds via
  `CGWindowListCopyWindowInfo`.
- `screencapture` is not permitted in the agent environment, and the agent cannot click the menu bar,
  so visual behaviour and the library/still-picker windows must be confirmed by the user.
- Verified: builds, launches, video plays at ~2-3% CPU, window is at desktop level on the main
  display. **Not verified:** pause on sleep/lock/battery, GIF playback, multi-display, Launch at
  Login after reboot, the two-tab window UI, the still picker window, activating a wallpaper, applying the default/custom still to the lock screen.

## Out of scope so far
Web/HTML wallpapers, Metal shaders, audio, animated lock screen, syncing with the system wallpaper
setting, per-display wallpapers.

## Workflow preferences
- Commit only when the user asks. Commit messages end with the `Co-Authored-By` line from the
  harness attribution reminder.

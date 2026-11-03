import AppKit
import ServiceManagement
import UniformTypeIdentifiers
import IOKit.ps

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let desktop = DesktopWindowController()
    private var renderer: WallpaperRenderer?
    private var statusItem: NSStatusItem!
    private var pauseItem: NSMenuItem!
    private var batteryItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private var nameItem: NSMenuItem!
    private var lowPowerItem: NSMenuItem!

    private var userPaused = false
    private var screenAsleep = false
    private var locked = false
    private var timer: Timer?
    private var currentURL: URL?
    private var mainController: MainWindowController?

    // openFile can arrive before didFinishLaunching, so set up UI first.
    func applicationWillFinishLaunching(_ notification: Notification) {
        buildMenu()
        observe()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if renderer == nil, let url = Settings.loadWallpaper() { load(url) }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updatePlayback()
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        activate(URL(fileURLWithPath: filename))
        return true
    }

    // MARK: Menu

    private func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "photo.on.rectangle.angled",
                                           accessibilityDescription: "AniWallpaper")
        let menu = NSMenu()
        nameItem = NSMenuItem(title: "No wallpaper selected", action: nil, keyEquivalent: "")
        menu.addItem(nameItem)
        menu.addItem(.separator())
        menu.addItem(item("Open Library…", #selector(openLibrary), "l"))
        pauseItem = item("Pause", #selector(togglePause), "p")
        menu.addItem(pauseItem)
        menu.addItem(.separator())
        batteryItem = item("Pause on Battery", #selector(toggleBattery))
        lowPowerItem = item("Pause on Low Power Mode", #selector(toggleLowPower))
        loginItem = item("Launch at Login", #selector(toggleLogin))
        menu.addItem(batteryItem)
        menu.addItem(lowPowerItem)
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(item("Quit AniWallpaper", #selector(NSApplication.terminate(_:)), "q", target: NSApp))
        menu.delegate = self
        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector, _ key: String = "", target: AnyObject? = nil) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = target ?? self
        return i
    }

    // MARK: Actions

    @objc private func openLibrary() {
        if mainController == nil {
            let c = MainWindowController()
            c.onActivate = { [weak self] url in self?.activate(url) }
            c.setActive(currentURL)
            mainController = c
            watchClose(of: c.window!)
        }
        present(mainController!.window!)
    }

    /// Windows from a menu-bar-only (accessory) app need a regular activation policy to take focus properly.
    private func present(_ window: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func watchClose(of window: NSWindow) {
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
            DispatchQueue.main.async { NSApp.setActivationPolicy(.accessory) }
        }
    }

    @objc private func togglePause() {
        userPaused.toggle()
        updatePlayback()
    }

    @objc private func toggleBattery() {
        Settings.pauseOnBattery.toggle()
        updatePlayback()
    }

    @objc private func toggleLowPower() {
        Settings.pauseOnLowPower.toggle()
        updatePlayback()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    // MARK: Playback

    /// User-initiated: make `url` the active wallpaper and, by default, use its first frame as the lock screen still.
    private func activate(_ url: URL) {
        Settings.saveWallpaper(url)
        Settings.stillTime = nil
        load(url)
        Task { @MainActor in
            do { try await LockScreenStill.apply(url: url, at: 0) }
            catch { NSLog("AniWallpaper: couldn't set default lock screen still: \(error)") }
        }
    }

    /// Plays `url` without touching the lock screen (also used to restore the saved wallpaper at launch).
    private func load(_ url: URL) {
        currentURL = url
        Library.shared.add([url])
        mainController?.setActive(url)
        renderer = RendererFactory.make(for: url)
        desktop.setRenderer(renderer)
        nameItem.title = url.lastPathComponent
        updatePlayback()
    }

    private var onBattery: Bool {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let type = IOPSGetProvidingPowerSourceType(info).takeRetainedValue() as String
        return type == kIOPSBatteryPowerValue
    }

    private var powerSavingPause: Bool {
        (Settings.pauseOnBattery && onBattery)
            || (Settings.pauseOnLowPower && ProcessInfo.processInfo.isLowPowerModeEnabled)
    }

    private func updatePlayback() {
        let shouldPlay = !userPaused && !screenAsleep && !locked
            && desktop.anyWindowVisible
            && !powerSavingPause
        if shouldPlay { renderer?.play() } else { renderer?.pause() }
    }

    private func observe() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.desktop.rebuild()
            self?.updatePlayback()
        }
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.screenAsleep = true; self?.updatePlayback()
        }
        ws.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.screenAsleep = false; self?.updatePlayback()
        }
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.locked = true; self?.updatePlayback()
        }
        dnc.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.locked = false; self?.updatePlayback()
        }
        nc.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: nil, queue: .main) { [weak self] _ in
            self?.updatePlayback()
        }
        nc.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.updatePlayback()
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        pauseItem.title = userPaused ? "Resume" : "Pause"
        batteryItem.state = Settings.pauseOnBattery ? .on : .off
        lowPowerItem.state = Settings.pauseOnLowPower ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }
}

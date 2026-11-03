import AppKit

/// Owns one borderless desktop-level window per screen.
final class DesktopWindowController {
    private(set) var windows: [NSWindow] = []
    private var renderer: WallpaperRenderer?

    var anyWindowVisible: Bool {
        windows.contains { $0.occlusionState.contains(.visible) }
    }

    func setRenderer(_ renderer: WallpaperRenderer?) {
        self.renderer?.pause()
        self.renderer = renderer
        rebuild()
    }

    func rebuild() {
        windows.forEach { $0.orderOut(nil) }
        windows = []
        guard let renderer else { return }

        for screen in NSScreen.screens {
            let window = NSWindow(contentRect: screen.frame, styleMask: .borderless,
                                  backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            window.isOpaque = true
            window.backgroundColor = .black
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.setFrame(screen.frame, display: false)
            window.contentView = renderer.makeView(frame: NSRect(origin: .zero, size: screen.frame.size))
            window.orderFrontRegardless()
            windows.append(window)
        }
    }
}

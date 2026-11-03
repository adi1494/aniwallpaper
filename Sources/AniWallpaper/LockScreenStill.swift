import AppKit

/// The lock screen shows the system wallpaper, so a "lock screen still" is a PNG set as the
/// desktop picture on every screen.
enum LockScreenStill {
    /// Extracts the full-resolution frame at `seconds` and applies it. Pass 0 for the default (first frame).
    @MainActor
    static func apply(url: URL, at seconds: Double) async throws {
        guard let cg = await FrameGrabber.frame(of: url, at: seconds, maxWidth: nil) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AniWallpaper/Stills", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Unique filename each time so macOS doesn't serve a cached copy of the old image.
        let name = url.deletingPathExtension().lastPathComponent
        let file = dir.appendingPathComponent("\(name)-\(Int(Date().timeIntervalSince1970)).png")
        guard let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try png.write(to: file)
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
            .allowClipping: true,
        ]
        for screen in NSScreen.screens {
            try NSWorkspace.shared.setDesktopImageURL(file, for: screen, options: options)
        }
    }
}

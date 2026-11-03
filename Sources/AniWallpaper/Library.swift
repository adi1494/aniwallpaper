import AppKit
import AVFoundation

/// Persistent list of wallpaper files shown in the library window.
final class Library {
    static let shared = Library()
    static let didChange = Notification.Name("AniWallpaperLibraryDidChange")
    private let key = "libraryPaths"

    private(set) var urls: [URL]

    private init() {
        let paths = UserDefaults.standard.stringArray(forKey: key) ?? []
        urls = paths.map { URL(fileURLWithPath: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    func add(_ newURLs: [URL]) {
        var changed = false
        for u in newURLs where !urls.contains(u) { urls.append(u); changed = true }
        if changed { save() }
    }

    func remove(_ url: URL) {
        urls.removeAll { $0 == url }
        save()
    }

    private func save() {
        UserDefaults.standard.set(urls.map(\.path), forKey: key)
        NotificationCenter.default.post(name: Library.didChange, object: nil)
    }
}

enum FrameGrabber {
    static func isGif(_ url: URL) -> Bool { url.pathExtension.lowercased() == "gif" }

    static func duration(of url: URL) async -> Double {
        guard !isGif(url), let d = try? await AVURLAsset(url: url).load(.duration) else { return 0 }
        let s = d.seconds
        return s.isFinite ? s : 0
    }

    /// Exact frame at `seconds`. `maxWidth` nil = full resolution.
    static func frame(of url: URL, at seconds: Double, maxWidth: CGFloat?) async -> CGImage? {
        if isGif(url) {
            return NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
        let gen = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        gen.appliesPreferredTrackTransform = true
        gen.requestedTimeToleranceBefore = .zero
        gen.requestedTimeToleranceAfter = .zero
        if let w = maxWidth { gen.maximumSize = CGSize(width: w, height: w) }
        let time = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
        return try? await gen.image(at: time).image
    }
}

enum Thumbnails {
    private static let cache = NSCache<NSURL, NSImage>()

    static func image(for url: URL) async -> NSImage? {
        if let hit = cache.object(forKey: url as NSURL) { return hit }
        let d = await FrameGrabber.duration(of: url)
        guard let cg = await FrameGrabber.frame(of: url, at: min(1, d / 2), maxWidth: 480) else { return nil }
        let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        cache.setObject(img, forKey: url as NSURL)
        return img
    }
}

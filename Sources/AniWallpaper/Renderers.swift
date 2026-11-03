import AppKit
import AVFoundation

/// A renderer owns the animation source and hands out one view per screen.
protocol WallpaperRenderer: AnyObject {
    func makeView(frame: NSRect) -> NSView
    func play()
    func pause()
}

final class VideoRenderer: WallpaperRenderer {
    private let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    init(url: URL) {
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
    }

    func makeView(frame: NSRect) -> NSView {
        let view = NSView(frame: frame)
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        view.layer = layer          // layer-hosting view
        view.wantsLayer = true
        return view
    }

    func play() { player.play() }
    func pause() { player.pause() }
}

final class GifRenderer: WallpaperRenderer {
    private let image: NSImage?
    private let views = NSHashTable<NSImageView>.weakObjects()
    private var playing = true

    init(url: URL) { image = NSImage(contentsOf: url) }

    func makeView(frame: NSRect) -> NSView {
        let view = NSImageView(frame: frame)
        view.image = image
        view.imageScaling = .scaleAxesIndependently
        view.animates = playing
        view.autoresizingMask = [.width, .height]
        views.add(view)
        return view
    }

    func play() { playing = true; views.allObjects.forEach { $0.animates = true } }
    func pause() { playing = false; views.allObjects.forEach { $0.animates = false } }
}

enum RendererFactory {
    static func make(for url: URL) -> WallpaperRenderer {
        url.pathExtension.lowercased() == "gif" ? GifRenderer(url: url) : VideoRenderer(url: url)
    }
}

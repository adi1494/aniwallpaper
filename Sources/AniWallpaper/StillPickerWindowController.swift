import AppKit

/// Lets the user scrub through a video and set one frame as the system wallpaper
/// (which macOS also uses for the lock screen).
final class StillPickerWindowController: NSWindowController {
    private let url: URL
    private var duration: Double = 0
    private let imageView = NSImageView()
    private let slider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let timeLabel = NSTextField(labelWithString: "0:00.0")
    private let setButton = NSButton(title: "Set as Lock Screen Still", target: nil, action: nil)
    private let status = NSTextField(labelWithString: "")
    private var previewTask: Task<Void, Never>?

    init(url: URL) {
        self.url = url
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
                         styleMask: [.titled, .closable, .resizable],
                         backing: .buffered, defer: false)
        w.title = "Lock Screen Still — \(url.lastPathComponent)"
        w.isReleasedWhenClosed = false
        w.minSize = NSSize(width: 480, height: 360)
        w.center()
        super.init(window: w)
        build(in: w)
        Task { @MainActor in
            duration = await FrameGrabber.duration(of: url)
            slider.maxValue = max(duration, 0.001)
            slider.isEnabled = duration > 0
            refreshPreview()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build(in w: NSWindow) {
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.black.cgColor
        imageView.layer?.cornerRadius = 8
        imageView.translatesAutoresizingMaskIntoConstraints = false

        slider.target = self
        slider.action = #selector(sliderMoved)
        slider.isContinuous = true
        slider.isEnabled = false
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)
        let sliderRow = NSStackView(views: [slider, timeLabel])
        sliderRow.spacing = 10
        sliderRow.translatesAutoresizingMaskIntoConstraints = false

        setButton.target = self
        setButton.action = #selector(setTapped)
        setButton.bezelStyle = .rounded
        setButton.keyEquivalent = "\r"
        status.textColor = .secondaryLabelColor
        status.lineBreakMode = .byTruncatingTail
        status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let bottom = NSStackView(views: [status, spacer, setButton])
        bottom.spacing = 10
        bottom.translatesAutoresizingMaskIntoConstraints = false

        let c = w.contentView!
        c.addSubview(imageView); c.addSubview(sliderRow); c.addSubview(bottom)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: c.topAnchor, constant: 16),
            imageView.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -16),
            imageView.bottomAnchor.constraint(equalTo: sliderRow.topAnchor, constant: -12),
            sliderRow.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 16),
            sliderRow.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -16),
            sliderRow.bottomAnchor.constraint(equalTo: bottom.topAnchor, constant: -12),
            bottom.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 16),
            bottom.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -16),
            bottom.bottomAnchor.constraint(equalTo: c.bottomAnchor, constant: -14),
        ])
    }

    @objc private func sliderMoved() { refreshPreview() }

    private func refreshPreview() {
        let t = slider.doubleValue
        timeLabel.stringValue = String(format: "%d:%04.1f", Int(t) / 60, t.truncatingRemainder(dividingBy: 60))
        previewTask?.cancel()
        previewTask = Task { @MainActor in
            guard let cg = await FrameGrabber.frame(of: url, at: t, maxWidth: 1280), !Task.isCancelled else { return }
            imageView.image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        }
    }

    @objc private func setTapped() {
        setButton.isEnabled = false
        status.stringValue = "Rendering full-resolution frame…"
        let t = slider.doubleValue
        Task { @MainActor in
            defer { setButton.isEnabled = true }
            guard let cg = await FrameGrabber.frame(of: url, at: t, maxWidth: nil) else {
                status.stringValue = "Couldn’t read that frame."
                return
            }
            do {
                try Self.applyAsSystemWallpaper(cg, name: url.deletingPathExtension().lastPathComponent)
                status.stringValue = "Done. Lock your Mac (⌃⌘Q) to see it."
            } catch {
                status.stringValue = "Failed: \(error.localizedDescription)"
            }
        }
    }

    static func applyAsSystemWallpaper(_ image: CGImage, name: String) throws {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AniWallpaper/Stills", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Unique filename each time so macOS doesn't serve a cached copy of the old image.
        let file = dir.appendingPathComponent("\(name)-\(Int(Date().timeIntervalSince1970)).png")
        guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
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

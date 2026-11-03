import AppKit

/// Separate window for choosing which frame of the active video is used as the lock screen still.
final class StillPickerWindowController: NSWindowController {
    private let url: URL
    private var duration: Double = 0
    private let imageView = NSImageView()
    private let slider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let timeLabel = NSTextField(labelWithString: "0:00.0")
    private let setButton = NSButton(title: "Set as Lock Screen Still", target: nil, action: nil)
    private let resetButton = NSButton(title: "Reset to Default Still", target: nil, action: nil)
    private let doneButton = NSButton(title: "Done", target: nil, action: nil)
    private let status = NSTextField(labelWithString: "")
    private var previewTask: Task<Void, Never>?

    init(url: URL) {
        self.url = url
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 540),
                         styleMask: [.titled, .closable, .resizable],
                         backing: .buffered, defer: false)
        w.title = "Select Lock Screen Still: \(url.lastPathComponent)"
        w.isReleasedWhenClosed = false
        w.minSize = NSSize(width: 560, height: 380)
        w.center()
        super.init(window: w)
        build(in: w)
        refreshStatus()
        Task { @MainActor in
            duration = await FrameGrabber.duration(of: url)
            slider.maxValue = max(duration, 0.001)
            slider.isEnabled = duration > 0
            slider.doubleValue = min(Settings.stillTime ?? 0, duration)
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

        setButton.target = self; setButton.action = #selector(setTapped)
        resetButton.target = self; resetButton.action = #selector(resetTapped)
        doneButton.target = self; doneButton.action = #selector(doneTapped)
        for b in [setButton, resetButton, doneButton] { b.bezelStyle = .rounded }
        doneButton.keyEquivalent = "\r"
        status.textColor = .secondaryLabelColor
        status.lineBreakMode = .byTruncatingTail
        status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let bottom = NSStackView(views: [status, spacer, resetButton, setButton, doneButton])
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

    private static func format(_ t: Double) -> String {
        String(format: "%d:%04.1f", Int(t) / 60, t.truncatingRemainder(dividingBy: 60))
    }

    private func refreshStatus() {
        if let t = Settings.stillTime {
            status.stringValue = "Lock screen still: frame at \(Self.format(t))"
        } else {
            status.stringValue = "Lock screen still: first frame (default)"
        }
    }

    @objc private func sliderMoved() { refreshPreview() }

    private func refreshPreview() {
        let t = slider.doubleValue
        timeLabel.stringValue = Self.format(t)
        previewTask?.cancel()
        previewTask = Task { @MainActor in
            guard let cg = await FrameGrabber.frame(of: url, at: t, maxWidth: 1280), !Task.isCancelled else { return }
            imageView.image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        }
    }

    @objc private func setTapped() { apply(at: slider.doubleValue, isDefault: false) }

    @objc private func resetTapped() {
        slider.doubleValue = 0
        refreshPreview()
        apply(at: 0, isDefault: true)
    }

    @objc private func doneTapped() { window?.close() }

    private func apply(at t: Double, isDefault: Bool) {
        [setButton, resetButton].forEach { $0.isEnabled = false }
        status.stringValue = "Applying…"
        Task { @MainActor in
            defer { [setButton, resetButton].forEach { $0.isEnabled = true } }
            do {
                try await LockScreenStill.apply(url: url, at: t)
                Settings.stillTime = isDefault ? nil : t
                refreshStatus()
            } catch {
                status.stringValue = "Failed: \(error.localizedDescription)"
            }
        }
    }
}

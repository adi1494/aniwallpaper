import AppKit

/// "Active Wallpaper" tab: shows only the wallpaper's thumbnail and file path, plus a button that
/// opens the lock screen still picker window.
final class ActiveWallpaperPane: NSView {
    private var url: URL?
    private let content = NSStackView()
    private let emptyLabel = NSTextField(labelWithString: "No active wallpaper. Set one from the Library tab.")
    private let thumbnail = NSImageView()
    private let pathLabel = NSTextField(labelWithString: "")
    private let selectStillButton = NSButton(title: "Select Still…", target: nil, action: nil)
    private var stillController: StillPickerWindowController?

    override init(frame: NSRect) {
        super.init(frame: frame)
        build()
        setActive(nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setActive(_ newURL: URL?) {
        if newURL != url {
            stillController?.window?.close()   // its video is no longer the active one
            stillController = nil
        }
        url = newURL
        content.isHidden = newURL == nil
        emptyLabel.isHidden = newURL != nil
        guard let newURL else { return }
        pathLabel.stringValue = newURL.path
        thumbnail.image = nil
        Task { @MainActor in
            let img = await Thumbnails.image(for: newURL)
            if self.url == newURL { self.thumbnail.image = img }
        }
    }

    private func build() {
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        thumbnail.imageScaling = .scaleProportionallyUpOrDown
        thumbnail.wantsLayer = true
        thumbnail.layer?.backgroundColor = NSColor.black.cgColor
        thumbnail.layer?.cornerRadius = 10
        thumbnail.layer?.masksToBounds = true
        thumbnail.translatesAutoresizingMaskIntoConstraints = false

        pathLabel.isSelectable = true
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.alignment = .center
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.translatesAutoresizingMaskIntoConstraints = false

        selectStillButton.target = self
        selectStillButton.action = #selector(selectStillTapped)
        selectStillButton.bezelStyle = .rounded

        content.orientation = .vertical
        content.alignment = .centerX
        content.spacing = 14
        content.addArrangedSubview(thumbnail)
        content.addArrangedSubview(pathLabel)
        content.addArrangedSubview(selectStillButton)
        content.translatesAutoresizingMaskIntoConstraints = false

        addSubview(content)
        addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            thumbnail.widthAnchor.constraint(equalToConstant: 480),
            thumbnail.heightAnchor.constraint(equalToConstant: 280),
            pathLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -48),
            content.centerXAnchor.constraint(equalTo: centerXAnchor),
            content.centerYAnchor.constraint(equalTo: centerYAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @objc private func selectStillTapped() {
        guard let url else { return }
        if let existing = stillController, existing.window?.isVisible == true {
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }
        let c = StillPickerWindowController(url: url)
        stillController = c
        c.showWindow(nil)
        c.window?.makeKeyAndOrderFront(nil)
    }
}

import AppKit

final class WallpaperCell: NSCollectionViewItem {
    static let id = NSUserInterfaceItemIdentifier("WallpaperCell")
    private var representedURL: URL?

    override func loadView() {
        let container = NSView()
        let iv = NSImageView()
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.wantsLayer = true
        iv.layer?.cornerRadius = 8
        iv.layer?.masksToBounds = true
        iv.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.15).cgColor
        iv.translatesAutoresizingMaskIntoConstraints = false
        let tf = NSTextField(labelWithString: "")
        tf.lineBreakMode = .byTruncatingMiddle
        tf.alignment = .center
        tf.font = .systemFont(ofSize: 12)
        tf.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iv)
        container.addSubview(tf)
        NSLayoutConstraint.activate([
            iv.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            iv.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            iv.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
            iv.bottomAnchor.constraint(equalTo: tf.topAnchor, constant: -6),
            tf.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            tf.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
            tf.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
        ])
        container.wantsLayer = true
        container.layer?.cornerRadius = 10
        view = container
        imageView = iv
        textField = tf
    }

    override var isSelected: Bool {
        didSet {
            view.layer?.backgroundColor = isSelected ? NSColor.controlAccentColor.withAlphaComponent(0.25).cgColor : nil
        }
    }

    func configure(url: URL) {
        representedURL = url
        textField?.stringValue = url.deletingPathExtension().lastPathComponent
        imageView?.image = nil
        Task { @MainActor in
            let img = await Thumbnails.image(for: url)
            if self.representedURL == url { self.imageView?.image = img }
        }
    }
}

final class LibraryWindowController: NSWindowController, NSCollectionViewDataSource, NSCollectionViewDelegate {
    var onApply: ((URL) -> Void)?
    var onPickStill: ((URL) -> Void)?

    private let collection = NSCollectionView()
    private let emptyLabel = NSTextField(labelWithString: "Click “Add…” to import videos or GIFs.")
    private let applyButton = NSButton(title: "Set as Wallpaper", target: nil, action: nil)
    private let stillButton = NSButton(title: "Choose Lock Screen Still…", target: nil, action: nil)
    private let removeButton = NSButton(title: "Remove", target: nil, action: nil)
    private let addButton = NSButton(title: "Add…", target: nil, action: nil)
    private let nowLabel = NSTextField(labelWithString: "")

    private var urls: [URL] { Library.shared.urls }

    init() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        w.title = "AniWallpaper Library"
        w.isReleasedWhenClosed = false
        w.minSize = NSSize(width: 560, height: 360)
        w.center()
        super.init(window: w)
        build(in: w)
        NotificationCenter.default.addObserver(forName: Library.didChange, object: nil, queue: .main) { [weak self] _ in
            self?.reload()
        }
        reload()
    }

    required init?(coder: NSCoder) { fatalError() }

    func setNowPlaying(_ name: String?) {
        nowLabel.stringValue = name.map { "Now playing: \($0)" } ?? ""
    }

    private func build(in w: NSWindow) {
        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 210, height: 170)
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        collection.collectionViewLayout = layout
        collection.dataSource = self
        collection.delegate = self
        collection.isSelectable = true
        collection.allowsMultipleSelection = false
        collection.backgroundColors = [.clear]
        collection.register(WallpaperCell.self, forItemWithIdentifier: WallpaperCell.id)
        let dbl = NSClickGestureRecognizer(target: self, action: #selector(doubleClicked(_:)))
        dbl.numberOfClicksRequired = 2
        dbl.delaysPrimaryMouseButtonEvents = false
        collection.addGestureRecognizer(dbl)

        let scroll = NSScrollView()
        scroll.documentView = collection
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        for (b, a) in [(addButton, #selector(addTapped)), (applyButton, #selector(applyTapped)),
                       (stillButton, #selector(stillTapped)), (removeButton, #selector(removeTapped))] {
            b.target = self; b.action = a; b.bezelStyle = .rounded
        }
        nowLabel.textColor = .secondaryLabelColor
        nowLabel.lineBreakMode = .byTruncatingMiddle
        nowLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let bar = NSStackView(views: [addButton, removeButton, nowLabel, spacer, stillButton, applyButton])
        bar.orientation = .horizontal
        bar.spacing = 10
        bar.translatesAutoresizingMaskIntoConstraints = false

        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        let content = w.contentView!
        content.addSubview(scroll)
        content.addSubview(bar)
        content.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: content.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bar.topAnchor, constant: -10),
            bar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            bar.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            bar.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
            emptyLabel.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: content.centerYAnchor),
        ])
    }

    private func reload() {
        collection.reloadData()
        emptyLabel.isHidden = !urls.isEmpty
        updateButtons()
    }

    private var selectedURL: URL? {
        guard let i = collection.selectionIndexPaths.first?.item, urls.indices.contains(i) else { return nil }
        return urls[i]
    }

    private func updateButtons() {
        let has = selectedURL != nil
        applyButton.isEnabled = has
        stillButton.isEnabled = has
        removeButton.isEnabled = has
    }

    // MARK: Actions

    @objc private func addTapped() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie, .gif]
        panel.allowsMultipleSelection = true
        panel.message = "Choose videos or GIFs to add to your library"
        guard panel.runModal() == .OK else { return }
        Library.shared.add(panel.urls)
    }

    @objc private func applyTapped() { if let u = selectedURL { onApply?(u) } }
    @objc private func stillTapped() { if let u = selectedURL { onPickStill?(u) } }
    @objc private func removeTapped() { if let u = selectedURL { Library.shared.remove(u) } }

    @objc private func doubleClicked(_ g: NSClickGestureRecognizer) {
        guard let ip = collection.indexPathForItem(at: g.location(in: collection)), urls.indices.contains(ip.item) else { return }
        onApply?(urls[ip.item])
    }

    // MARK: Data source / delegate

    func collectionView(_ cv: NSCollectionView, numberOfItemsInSection section: Int) -> Int { urls.count }

    func collectionView(_ cv: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = cv.makeItem(withIdentifier: WallpaperCell.id, for: indexPath) as! WallpaperCell
        item.configure(url: urls[indexPath.item])
        return item
    }

    func collectionView(_ cv: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) { updateButtons() }
    func collectionView(_ cv: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) { updateButtons() }
}

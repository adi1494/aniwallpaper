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

    func configure(url: URL, isActive: Bool) {
        representedURL = url
        let name = url.deletingPathExtension().lastPathComponent
        textField?.stringValue = isActive ? "● \(name)" : name
        textField?.font = isActive ? .boldSystemFont(ofSize: 12) : .systemFont(ofSize: 12)
        imageView?.image = nil
        Task { @MainActor in
            let img = await Thumbnails.image(for: url)
            if self.representedURL == url { self.imageView?.image = img }
        }
    }
}

/// Single window with two tabs: Library and Active Wallpaper.
final class MainWindowController: NSWindowController, NSCollectionViewDataSource, NSCollectionViewDelegate {
    /// Called when the user sets a wallpaper active from the Library tab.
    var onActivate: ((URL) -> Void)?

    private(set) var activeURL: URL?
    private let tabView = NSTabView()
    private let pane = ActiveWallpaperPane()

    private let collection = NSCollectionView()
    private let emptyLabel = NSTextField(labelWithString: "Click “Add…” to import videos or GIFs.")
    private let activateButton = NSButton(title: "Set as Active Wallpaper", target: nil, action: nil)
    private let removeButton = NSButton(title: "Remove", target: nil, action: nil)
    private let addButton = NSButton(title: "Add…", target: nil, action: nil)

    private var urls: [URL] { Library.shared.urls }

    init() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 840, height: 620),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        w.title = "AniWallpaper"
        w.isReleasedWhenClosed = false
        w.minSize = NSSize(width: 600, height: 420)
        w.center()
        super.init(window: w)
        build(in: w)
        NotificationCenter.default.addObserver(forName: Library.didChange, object: nil, queue: .main) { [weak self] _ in
            self?.reload()
        }
        reload()
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Called by the app whenever the active wallpaper changes (including at launch).
    func setActive(_ url: URL?) {
        activeURL = url
        pane.setActive(url)
        reload()
    }

    private func build(in w: NSWindow) {
        let libraryTab = NSTabViewItem(identifier: "library")
        libraryTab.label = "Library"
        libraryTab.view = buildLibraryView()
        let activeTab = NSTabViewItem(identifier: "active")
        activeTab.label = "Active Wallpaper"
        activeTab.view = pane
        tabView.addTabViewItem(libraryTab)
        tabView.addTabViewItem(activeTab)
        tabView.translatesAutoresizingMaskIntoConstraints = false
        let c = w.contentView!
        c.addSubview(tabView)
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: c.topAnchor, constant: 8),
            tabView.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 8),
            tabView.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -8),
            tabView.bottomAnchor.constraint(equalTo: c.bottomAnchor, constant: -8),
        ])
    }

    private func buildLibraryView() -> NSView {
        let root = NSView()

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

        for (b, a) in [(addButton, #selector(addTapped)), (activateButton, #selector(activateTapped)),
                       (removeButton, #selector(removeTapped))] {
            b.target = self; b.action = a; b.bezelStyle = .rounded
        }
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let bar = NSStackView(views: [addButton, removeButton, spacer, activateButton])
        bar.orientation = .horizontal
        bar.spacing = 10
        bar.translatesAutoresizingMaskIntoConstraints = false

        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(scroll)
        root.addSubview(bar)
        root.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: root.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bar.topAnchor, constant: -10),
            bar.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            bar.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            bar.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
            emptyLabel.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: root.centerYAnchor),
        ])
        return root
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
        let sel = selectedURL
        let isActive = sel != nil && sel == activeURL
        activateButton.isEnabled = sel != nil && !isActive
        removeButton.isEnabled = sel != nil && !isActive
        removeButton.toolTip = isActive ? "The active wallpaper can’t be removed. Set another one active first." : nil
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

    @objc private func activateTapped() {
        if let u = selectedURL, u != activeURL { onActivate?(u) }
    }

    @objc private func removeTapped() {
        guard let u = selectedURL, u != activeURL else { return }   // never remove the active wallpaper
        Library.shared.remove(u)
    }

    @objc private func doubleClicked(_ g: NSClickGestureRecognizer) {
        guard let ip = collection.indexPathForItem(at: g.location(in: collection)), urls.indices.contains(ip.item) else { return }
        let u = urls[ip.item]
        if u != activeURL { onActivate?(u) }
    }

    // MARK: Data source / delegate

    func collectionView(_ cv: NSCollectionView, numberOfItemsInSection section: Int) -> Int { urls.count }

    func collectionView(_ cv: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = cv.makeItem(withIdentifier: WallpaperCell.id, for: indexPath) as! WallpaperCell
        let u = urls[indexPath.item]
        item.configure(url: u, isActive: u == activeURL)
        return item
    }

    func collectionView(_ cv: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) { updateButtons() }
    func collectionView(_ cv: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) { updateButtons() }
}

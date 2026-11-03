import Foundation

enum Settings {
    private static let bookmarkKey = "wallpaperBookmark"
    private static let batteryKey = "pauseOnBattery"

    static func saveWallpaper(_ url: URL) {
        if let data = try? url.bookmarkData() {
            UserDefaults.standard.set(data, forKey: bookmarkKey)
        }
    }

    static func loadWallpaper() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale) else { return nil }
        if stale { saveWallpaper(url) }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static var pauseOnBattery: Bool {
        get { UserDefaults.standard.bool(forKey: batteryKey) }
        set { UserDefaults.standard.set(newValue, forKey: batteryKey) }
    }
}

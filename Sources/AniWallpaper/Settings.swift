import Foundation

enum Settings {
    private static let bookmarkKey = "wallpaperBookmark"
    private static let batteryKey = "pauseOnBattery"
    private static let lowPowerKey = "pauseOnLowPower"
    private static let stillKey = "lockScreenStillTime"

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

    static var pauseOnLowPower: Bool {
        get { UserDefaults.standard.bool(forKey: lowPowerKey) }
        set { UserDefaults.standard.set(newValue, forKey: lowPowerKey) }
    }

    /// Seconds into the active video chosen as the lock screen still. nil = default (first frame).
    static var stillTime: Double? {
        get { UserDefaults.standard.object(forKey: stillKey) as? Double }
        set {
            if let v = newValue { UserDefaults.standard.set(v, forKey: stillKey) }
            else { UserDefaults.standard.removeObject(forKey: stillKey) }
        }
    }
}

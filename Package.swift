// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AniWallpaper",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "AniWallpaper", path: "Sources/AniWallpaper")
    ]
)

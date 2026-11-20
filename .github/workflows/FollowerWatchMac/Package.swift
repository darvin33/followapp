// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FollowerWatchMac",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "FollowerWatchMac", targets: ["FollowerWatchMac"])],
    targets: [.executableTarget(name: "FollowerWatchMac")]
)

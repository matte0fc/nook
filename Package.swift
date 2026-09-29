// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Nook",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Nook",
            path: "Sources/Nook"
        )
    ]
)

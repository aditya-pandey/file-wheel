// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FileWheel",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "FileWheel", targets: ["FileWheel"])
    ],
    targets: [
        .executableTarget(
            name: "FileWheel",
            path: "Sources/FileWheel"
        )
    ]
)

// swift-tools-version:5.9
// Manifest for opening the project in Xcode or building with a working SwiftPM.
// The canonical build path is `make` (Scripts/build-app.sh), which invokes swiftc directly.
import PackageDescription

let package = Package(
    name: "Debrowse",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Debrowse",
            path: "Sources/Debrowse",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ServiceManagement"),
            ]
        )
    ]
)

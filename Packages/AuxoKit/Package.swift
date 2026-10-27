// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AuxoKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "AuxoCore", targets: ["AuxoCore"]),
        .library(name: "AuxoProviders", targets: ["AuxoProviders"]),
        .library(name: "AuxoUI", targets: ["AuxoUI"]),
    ],
    targets: [
        // Source-agnostic model, stats, storage. No UI, no network specifics.
        .target(name: "AuxoCore"),
        // One provider per site (GitHub, LeetCode, Codeforces) plus the sync service.
        .target(name: "AuxoProviders", dependencies: ["AuxoCore"]),
        // SwiftUI pieces shared by the app and the widget.
        .target(name: "AuxoUI", dependencies: ["AuxoCore"]),

        .testTarget(name: "AuxoCoreTests", dependencies: ["AuxoCore"]),
        .testTarget(name: "AuxoProvidersTests", dependencies: ["AuxoProviders"]),
    ]
)

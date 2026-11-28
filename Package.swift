// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sero",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Sero", targets: ["Sero"]),
        // A developer tools package: downloaded on request, never in the
        // app (build.sh devtools, DevToolsPackages.swift).
        .library(name: "DevToolsLite", type: .dynamic, targets: ["DevToolsLite"]),
        .library(name: "DevToolsFull", type: .dynamic, targets: ["DevToolsFull"]),
    ],
    targets: [
        // What Sero and a developer tools package say to each other.
        .target(
            name: "SeroPluginAPI",
            path: "Sources/SeroPluginAPI",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "DevToolsLite",
            dependencies: ["SeroPluginAPI"],
            path: "Sources/DevToolsLite",
            // What build.sh puts in the feed for it, not code.
            exclude: ["package.json"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Developer Tools Full: the Chrome-style panels. Its Lighthouse,
        // Recorder and device toolbar are Lite's, the same sources compiled
        // into each (Sources/DevToolsShared, linked in as Shared/).
        .target(
            name: "DevToolsFull",
            dependencies: ["SeroPluginAPI"],
            path: "Sources/DevToolsFull",
            exclude: ["package.json"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Sero",
            dependencies: ["SeroPluginAPI"],
            path: "Sources/Sero",
            // The whole interface is
            // main-thread by nature, and Swift 6's strict isolation buys nothing
            // here but ceremony.
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Test-only: keeps every window the unit tests make off the screen.
        .target(
            name: "NoWindows",
            path: "Tests/NoWindows",
            linkerSettings: [.linkedFramework("AppKit")]
        ),
        .testTarget(
            name: "SeroTests",
            dependencies: ["Sero", "NoWindows"],
            path: "Tests/SeroTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)

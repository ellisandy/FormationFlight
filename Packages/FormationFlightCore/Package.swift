// swift-tools-version: 6.2
//
// Shared, platform-neutral flight logic for the iPhone app, its Live Activity widget and the
// Apple Watch companion. Pure value types only: no UI, no Core Location, no persistence, so the
// whole package builds and tests on macOS with `swift test`.

import PackageDescription

let package = Package(
    name: "FormationFlightCore",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v26),
        .watchOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "FormationFlightCore", targets: ["FormationFlightCore"]),
    ],
    targets: [
        .target(
            name: "FormationFlightCore",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "FormationFlightCoreTests",
            dependencies: ["FormationFlightCore"]
        ),
    ]
)

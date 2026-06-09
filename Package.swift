// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "AgentPrivacyLock",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "agent-privacy-lock", targets: ["AgentPrivacyLock"]),
        .executable(name: "agent-privacy-lock-client", targets: ["AgentPrivacyLockClient"]),
        .library(name: "AgentPrivacyLockCore", targets: ["AgentPrivacyLockCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .target(name: "AgentPrivacyLockCore"),
        .executableTarget(
            name: "AgentPrivacyLock",
            dependencies: ["AgentPrivacyLockCore"]
        ),
        .executableTarget(
            name: "AgentPrivacyLockClient",
            dependencies: [
                "AgentPrivacyLockCore",
                .product(name: "Sparkle", package: "Sparkle")
            ]
        ),
        .testTarget(
            name: "AgentPrivacyLockCoreTests",
            dependencies: ["AgentPrivacyLockCore"]
        )
    ]
)

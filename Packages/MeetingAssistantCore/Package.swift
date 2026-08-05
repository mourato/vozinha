// swift-tools-version: 6.2
// Swift Package for MeetingAssistantCore library

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "MeetingAssistantCore",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "MeetingAssistantCoreUI",
            type: .dynamic,
            targets: ["MeetingAssistantCoreUI"],
        ),
        .library(
            name: "MeetingAssistantCore",
            targets: ["MeetingAssistantCore"],
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/altic-dev/FluidAudio.git", branch: "B/cohere-coreml-asr"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-atomics.git", .upToNextMajor(from: "1.2.0")),
        .package(url: "https://github.com/apple/swift-syntax.git", exact: "602.0.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
        .package(url: "https://github.com/nodes-app/swift-markdown-engine", exact: "0.6.0"),
    ],
    targets: [
        .target(
            name: "MeetingAssistantCoreCommon",
            path: "Sources/Common",
            resources: [
                .process("Resources"),
            ],
        ),
        .target(
            name: "MeetingAssistantCoreDomain",
            dependencies: [
                "MeetingAssistantCoreCommon",
                "MeetingAssistantCoreMocking",
            ],
            path: "Sources/Domain",
        ),
        .target(
            name: "MeetingAssistantCoreData",
            dependencies: [
                "MeetingAssistantCoreCommon",
                "MeetingAssistantCoreDomain",
                "MeetingAssistantCoreInfrastructure",
            ],
            path: "Sources/Data",
        ),
        .target(
            name: "MeetingAssistantCoreInfrastructure",
            dependencies: [
                "MeetingAssistantCoreCommon",
                "MeetingAssistantCoreDomain",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/Infrastructure",
        ),
        .target(
            name: "MeetingAssistantCoreAudio",
            dependencies: [
                "MeetingAssistantCoreCommon",
                "MeetingAssistantCoreData",
                "MeetingAssistantCoreDomain",
                "MeetingAssistantCoreInfrastructure",
                .product(name: "Atomics", package: "swift-atomics"),
            ],
            path: "Sources/Audio",
        ),
        .target(
            name: "MeetingAssistantCoreAI",
            dependencies: [
                "MeetingAssistantCoreCommon",
                "MeetingAssistantCoreData",
                "MeetingAssistantCoreDomain",
                "MeetingAssistantCoreInfrastructure",
                .product(name: "FluidAudio", package: "FluidAudio"),
            ],
            path: "Sources/AI",
        ),
        .target(
            name: "MeetingAssistantCoreUI",
            dependencies: [
                "MeetingAssistantCoreAI",
                "MeetingAssistantCoreAudio",
                "MeetingAssistantCoreCommon",
                "MeetingAssistantCoreData",
                "MeetingAssistantCoreDomain",
                "MeetingAssistantCoreInfrastructure",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "MarkdownEngine", package: "swift-markdown-engine"),
            ],
            path: "Sources/UI",
            resources: [
                .process("Resources"),
            ],
        ),
        .target(
            name: "MeetingAssistantCore",
            dependencies: [
                "MeetingAssistantCoreAI",
                "MeetingAssistantCoreAudio",
                "MeetingAssistantCoreCommon",
                "MeetingAssistantCoreData",
                "MeetingAssistantCoreDomain",
                "MeetingAssistantCoreInfrastructure",
                "MeetingAssistantCoreUI",
            ],
            path: "Sources/Core",
        ),
        .target(
            name: "MeetingAssistantCoreMocking",
            dependencies: [
                "MeetingAssistantCoreMockingMacros",
            ],
            path: "Sources/Mocking",
        ),
        .macro(
            name: "MeetingAssistantCoreMockingMacros",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            ],
            path: "Sources/MockingMacros",
        ),
        .testTarget(
            name: "MeetingAssistantCoreTests",
            dependencies: [
                "MeetingAssistantCore",
                "MeetingAssistantCoreAI",
                "MeetingAssistantCoreAudio",
                "MeetingAssistantCoreUI",
                "MeetingAssistantCoreDomain",
            ],
            path: "Tests/MeetingAssistantCoreTests",
            resources: [
                .process("Resources"),
            ],
        ),
    ],
    swiftLanguageModes: [.v6],
)

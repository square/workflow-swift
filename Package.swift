// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Workflow",
    platforms: [
        .iOS("11.0"),
        .macOS("10.13"),
    ],
    products: [
        .library(
            name: "Workflow",
            targets: ["Workflow"]
        ),
        .library(
            name: "WorkflowUI",
            targets: ["WorkflowUI"]
        ),
        .library(
            name: "WorkflowSwiftUI",
            targets: ["WorkflowSwiftUI"]
        ),
        .library(
            name: "WorkflowReactiveSwift",
            targets: ["WorkflowReactiveSwift"]
        ),
        .library(
            name: "WorkflowCombine",
            targets: ["WorkflowCombine"]
        ),
        .library(
            name: "WorkflowTesting",
            targets: ["WorkflowTesting"]
        ),
        .library(
            name: "WorkflowReactiveSwiftTesting",
            targets: ["WorkflowReactiveSwiftTesting"]
        ),
        .library(
            name: "WorkflowCombineTesting",
            targets: ["WorkflowCombineTesting"]
        ),
        .library(
            name: "WorkflowConcurrency",
            targets: ["WorkflowConcurrency"]
        ),
        .library(
            name: "WorkflowConcurrencyTesting",
            targets: ["WorkflowConcurrencyTesting"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift.git", from: "6.3.0"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat", .exact("0.44.14")),
    ],
    targets: [
        .target(
            name: "Workflow",
            dependencies: ["ReactiveSwift"],
            path: "Workflow/Sources"
        ),
        .testTarget(
            name: "WorkflowTests",
            dependencies: ["Workflow"],
            path: "Workflow/Tests"
        ),
        .target(
            name: "WorkflowUI",
            dependencies: ["Workflow"],
            path: "WorkflowUI/Sources"
        ),
        .testTarget(
            name: "WorkflowUITests",
            dependencies: ["WorkflowUI", "WorkflowReactiveSwift"],
            path: "WorkflowUI/Tests"
        ),
        .target(
            name: "WorkflowSwiftUI",
            dependencies: ["ReactiveSwift", "Workflow"],
            path: "WorkflowSwiftUI/Sources"
        ),
        .target(
            name: "WorkflowReactiveSwift",
            dependencies: ["ReactiveSwift", "Workflow"],
            path: "WorkflowReactiveSwift/Sources"
        ),
        .testTarget(
            name: "WorkflowReactiveSwiftTests",
            dependencies: ["WorkflowReactiveSwiftTesting"],
            path: "WorkflowReactiveSwift/Tests"
        ),
        .target(
            name: "WorkflowCombine",
            dependencies: ["Workflow"],
            path: "WorkflowCombine/Sources"
        ),
        .testTarget(
            name: "WorkflowCombineTests",
            dependencies: ["WorkflowCombineTesting"],
            path: "WorkflowCombine/Tests"
        ),
        .testTarget(
            name: "WorkflowCombineTestingTests",
            dependencies: ["WorkflowCombineTesting"],
            path: "WorkflowCombine/TestingTests"
        ),
        .target(
            name: "WorkflowTesting",
            dependencies: ["Workflow"],
            path: "WorkflowTesting/Sources"
        ),
        .target(
            name: "WorkflowReactiveSwiftTesting",
            dependencies: ["WorkflowReactiveSwift", "WorkflowTesting"],
            path: "WorkflowReactiveSwift/Testing"
        ),
        .target(
            name: "WorkflowCombineTesting",
            dependencies: ["WorkflowCombine", "WorkflowTesting"],
            path: "WorkflowCombine/Testing"
        ),
        .target(
            name: "WorkflowConcurrency",
            dependencies: ["Workflow"],
            path: "WorkflowConcurrency/Sources"
        ),
        .testTarget(
            name: "WorkflowConcurrencyTests",
            dependencies: ["WorkflowConcurrency", "Workflow", "WorkflowTesting"],
            path: "WorkflowConcurrency/Tests"
        ),
        .target(
            name: "WorkflowConcurrencyTesting",
            dependencies: ["WorkflowConcurrency", "WorkflowTesting"],
            path: "WorkflowConcurrency/Testing"
        ),
        .testTarget(
            name: "WorkflowConcurrencyTestingTests",
            dependencies: ["WorkflowConcurrencyTesting"],
            path: "WorkflowConcurrency/TestingTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)

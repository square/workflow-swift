// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Workflow",
    platforms: [
        .iOS("14.0"),
        .macOS("10.15"),
    ],
    products: [
        // MARK: Workflow

        .library(
            name: "Workflow",
            targets: ["Workflow"]
        ),
        .library(
            name: "WorkflowTesting",
            targets: ["WorkflowTesting"]
        ),

        // MARK: WorkflowUI

        .library(
            name: "WorkflowUI",
            targets: ["WorkflowUI"]
        ),
        .library(
            name: "WorkflowSwiftUI",
            targets: ["WorkflowSwiftUI"]
        ),

        // MARK: WorkflowReactiveSwift

        .library(
            name: "WorkflowReactiveSwift",
            targets: ["WorkflowReactiveSwift"]
        ),
        .library(
            name: "WorkflowReactiveSwiftTesting",
            targets: ["WorkflowReactiveSwiftTesting"]
        ),

        // MARK: WorkflowRxSwift

        .library(
            name: "WorkflowRxSwift",
            targets: ["WorkflowRxSwift"]
        ),
        .library(
            name: "WorkflowRxSwiftTesting",
            targets: ["WorkflowRxSwiftTesting"]
        ),

        // MARK: WorkflowCombine

        .library(
            name: "WorkflowCombine",
            targets: ["WorkflowCombine"]
        ),
        .library(
            name: "WorkflowCombineTesting",
            targets: ["WorkflowCombineTesting"]
        ),

        // MARK: WorkflowConcurrency

        .library(
            name: "WorkflowConcurrency",
            targets: ["WorkflowConcurrency"]
        ),
        .library(
            name: "WorkflowConcurrencyTesting",
            targets: ["WorkflowConcurrencyTesting"]
        ),

        // MARK: ViewEnvironment

        .library(
            name: "ViewEnvironment",
            targets: ["ViewEnvironment"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift.git", from: "7.1.1"),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", from: "6.2.0"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat", exact: "0.44.14"),
    ],
    targets: [
        // MARK: Workflow

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
            name: "WorkflowTesting",
            dependencies: ["Workflow"],
            path: "WorkflowTesting/Sources"
        ),
        .testTarget(
            name: "WorkflowTestingTests",
            dependencies: ["WorkflowTesting"],
            path: "WorkflowTesting/Tests"
        ),

        // MARK: WorkflowUI

        .target(
            name: "WorkflowUI",
            dependencies: ["Workflow", "ViewEnvironment"],
            path: "WorkflowUI/Sources"
        ),
        .testTarget(
            name: "WorkflowUITests",
            dependencies: ["WorkflowUI", "WorkflowReactiveSwift"],
            path: "WorkflowUI/Tests"
        ),
        .target(
            name: "WorkflowSwiftUI",
            dependencies: ["Workflow"],
            path: "WorkflowSwiftUI/Sources"
        ),

        // MARK: WorkflowReactiveSwift

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
            name: "WorkflowReactiveSwiftTesting",
            dependencies: ["WorkflowReactiveSwift", "WorkflowTesting"],
            path: "WorkflowReactiveSwift/Testing"
        ),
        .testTarget(
            name: "WorkflowReactiveSwiftTestingTests",
            dependencies: ["WorkflowReactiveSwiftTesting"],
            path: "WorkflowReactiveSwift/TestingTests"
        ),

        // MARK: WorkflowRxSwift

        .target(
            name: "WorkflowRxSwift",
            dependencies: ["RxSwift", "Workflow"],
            path: "WorkflowRxSwift/Sources"
        ),
        .testTarget(
            name: "WorkflowRxSwiftTests",
            dependencies: ["WorkflowRxSwiftTesting", "WorkflowReactiveSwift"],
            path: "WorkflowRxSwift/Tests"
        ),
        .target(
            name: "WorkflowRxSwiftTesting",
            dependencies: ["WorkflowRxSwift", "WorkflowTesting"],
            path: "WorkflowRxSwift/Testing"
        ),
        .testTarget(
            name: "WorkflowRxSwiftTestingTests",
            dependencies: ["WorkflowRxSwiftTesting"],
            path: "WorkflowRxSwift/TestingTests"
        ),

        // MARK: WorkflowCombine

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
        .target(
            name: "WorkflowCombineTesting",
            dependencies: ["WorkflowCombine", "WorkflowTesting"],
            path: "WorkflowCombine/Testing"
        ),
        .testTarget(
            name: "WorkflowCombineTestingTests",
            dependencies: ["WorkflowCombineTesting"],
            path: "WorkflowCombine/TestingTests"
        ),

        // MARK: WorkflowConcurrency

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

        // MARK: ViewEnvironment

        .target(
            name: "ViewEnvironment",
            path: "ViewEnvironment/Sources"
        ),
    ],
    swiftLanguageVersions: [.v5]
)

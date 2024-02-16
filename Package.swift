// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Workflow",
    platforms: [
        .iOS("15.0"),
        .macOS("10.15"),
        .watchOS("8.0"),
    ],
    products: [
        // MARK: Workflow

        .singleTargetLibrary("Workflow"),
        .singleTargetLibrary("WorkflowTesting"),

        // MARK: WorkflowUI

        .singleTargetLibrary("WorkflowUI"),
        .singleTargetLibrary("WorkflowSwiftUI"),

        // MARK: WorkflowReactiveSwift

        .singleTargetLibrary("WorkflowReactiveSwift"),
        .singleTargetLibrary("WorkflowReactiveSwiftTesting"),

        // MARK: WorkflowRxSwift

        .singleTargetLibrary("WorkflowRxSwift"),
        .singleTargetLibrary("WorkflowRxSwiftTesting"),

        // MARK: WorkflowCombine

        .singleTargetLibrary("WorkflowCombine"),
        .singleTargetLibrary("WorkflowCombineTesting"),

        // MARK: WorkflowConcurrency

        .singleTargetLibrary("WorkflowConcurrency"),
        .singleTargetLibrary("WorkflowConcurrencyTesting"),

        // MARK: ViewEnvironment

        .singleTargetLibrary("ViewEnvironment"),

        // MARK: ViewEnvironmentUI

        .singleTargetLibrary("ViewEnvironmentUI"),
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift.git", from: "7.1.1"),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", from: "6.6.0"),
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
            dependencies: ["Workflow", "ViewEnvironment", "ViewEnvironmentUI"],
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

        // MARK: ViewEnvironmentUI

        .target(
            name: "ViewEnvironmentUI",
            dependencies: ["ViewEnvironment"],
            path: "ViewEnvironmentUI/Sources"
        ),
    ],
    swiftLanguageVersions: [.v5]
)

// MARK: Helpers

extension PackageDescription.Product {
    static func singleTargetLibrary(
        _ name: String
    ) -> PackageDescription.Product {
        .library(name: name, targets: [name])
    }
}

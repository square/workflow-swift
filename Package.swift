// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "Workflow",
    platforms: [
        .iOS(.v16),
        .macOS(.v12),
        .watchOS(.v8),
        .macCatalyst(.v16),
        .tvOS(.v12),
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
        .package(url: "https://github.com/swiftlang/swift-syntax", "509.0.0" ..< "601.0.0-prerelease"),
        .package(url: "https://github.com/pointfreeco/swift-case-paths", from: "1.5.5"),
        .package(url: "https://github.com/pointfreeco/swift-identified-collections", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing", from: "0.4.0"),
        .package(url: "https://github.com/pointfreeco/swift-perception", "1.5.0"..<"3.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.3.3"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.0.0"),
    ],
    targets: [
        // MARK: Workflow

        .target(
            name: "Workflow",
            dependencies: ["ReactiveSwift"],
            path: "Workflow/Sources"
        ),
        .target(
            name: "WorkflowTesting",
            dependencies: [
                "Workflow",
                .product(name: "CustomDump", package: "swift-custom-dump"),
            ],
            path: "WorkflowTesting/Sources",
            linkerSettings: [.linkedFramework("XCTest")]
        ),

        // MARK: WorkflowUI

        .target(
            name: "WorkflowUI",
            dependencies: ["Workflow", "ViewEnvironment", "ViewEnvironmentUI"],
            path: "WorkflowUI/Sources"
        ),

        // MARK: WorkflowSwiftUI

        .target(
            name: "WorkflowSwiftUI",
            dependencies: [
                "Workflow",
                "WorkflowUI",
                "WorkflowSwiftUIMacros",
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "IdentifiedCollections", package: "swift-identified-collections"),
                .product(name: "Perception", package: "swift-perception"),
            ],
            path: "WorkflowSwiftUI/Sources"
        ),
        .macro(
            name: "WorkflowSwiftUIMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            path: "WorkflowSwiftUIMacros/Sources"
        ),
        // Macro test targets are not yet supported in Tuist, see note in Project.swift
        .testTarget(
            name: "WorkflowSwiftUIMacrosTests",
            dependencies: [
                "WorkflowSwiftUIMacros",
                .product(name: "MacroTesting", package: "swift-macro-testing"),
            ],
            path: "WorkflowSwiftUIMacros/Tests"
        ),

        // MARK: WorkflowReactiveSwift

        .target(
            name: "WorkflowReactiveSwift",
            dependencies: ["ReactiveSwift", "Workflow"],
            path: "WorkflowReactiveSwift/Sources"
        ),
        .target(
            name: "WorkflowReactiveSwiftTesting",
            dependencies: ["WorkflowReactiveSwift", "WorkflowTesting"],
            path: "WorkflowReactiveSwift/Testing",
            linkerSettings: [.linkedFramework("XCTest")]
        ),

        // MARK: WorkflowRxSwift

        .target(
            name: "WorkflowRxSwift",
            dependencies: ["RxSwift", "Workflow"],
            path: "WorkflowRxSwift/Sources"
        ),
        .target(
            name: "WorkflowRxSwiftTesting",
            dependencies: ["WorkflowRxSwift", "WorkflowTesting"],
            path: "WorkflowRxSwift/Testing",
            linkerSettings: [.linkedFramework("XCTest")]
        ),

        // MARK: WorkflowCombine

        .target(
            name: "WorkflowCombine",
            dependencies: ["Workflow"],
            path: "WorkflowCombine/Sources"
        ),
        .target(
            name: "WorkflowCombineTesting",
            dependencies: ["WorkflowCombine", "WorkflowTesting"],
            path: "WorkflowCombine/Testing",
            linkerSettings: [.linkedFramework("XCTest")]
        ),

        // MARK: WorkflowConcurrency

        .target(
            name: "WorkflowConcurrency",
            dependencies: ["Workflow"],
            path: "WorkflowConcurrency/Sources"
        ),
        .target(
            name: "WorkflowConcurrencyTesting",
            dependencies: ["WorkflowConcurrency", "WorkflowTesting"],
            path: "WorkflowConcurrency/Testing",
            linkerSettings: [.linkedFramework("XCTest")]
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

for target in package.targets {
    var settings = target.swiftSettings ?? []
    settings.append(.enableExperimentalFeature("StrictConcurrency=targeted"))
    target.swiftSettings = settings
}

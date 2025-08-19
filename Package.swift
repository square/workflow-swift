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
        .package(url: "https://github.com/pointfreeco/swift-perception", from: "2.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.2.1"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", from: "1.0.0"),
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
            dependencies: [
                "Workflow",
                .product(name: "CustomDump", package: "swift-custom-dump"),
            ],
            path: "WorkflowTesting/Sources",
            linkerSettings: [.linkedFramework("XCTest")]
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
        .testTarget(
            name: "WorkflowSwiftUITests",
            dependencies: ["WorkflowSwiftUI"],
            path: "WorkflowSwiftUI/Tests"
        ),
        .macro(
            name: "WorkflowSwiftUIMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            path: "WorkflowSwiftUIMacros/Sources"
        ),
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
        .testTarget(
            name: "WorkflowReactiveSwiftTests",
            dependencies: ["WorkflowReactiveSwiftTesting"],
            path: "WorkflowReactiveSwift/Tests"
        ),
        .target(
            name: "WorkflowReactiveSwiftTesting",
            dependencies: ["WorkflowReactiveSwift", "WorkflowTesting"],
            path: "WorkflowReactiveSwift/Testing",
            linkerSettings: [.linkedFramework("XCTest")]
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
            path: "WorkflowRxSwift/Testing",
            linkerSettings: [.linkedFramework("XCTest")]
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
            path: "WorkflowCombine/Testing",
            linkerSettings: [.linkedFramework("XCTest")]
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
            path: "WorkflowConcurrency/Testing",
            linkerSettings: [.linkedFramework("XCTest")]
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

for target in package.targets {
    var settings = target.swiftSettings ?? []
    settings.append(.enableExperimentalFeature("StrictConcurrency=targeted"))
    target.swiftSettings = settings
}

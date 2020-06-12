// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Workflow",
    platforms: [
        .iOS("10.0"),
        .macOS("10.12"),
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
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift.git", from: "6.3.0"),
        .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.44.9"),
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
            dependencies: ["WorkflowUI"],
            path: "WorkflowUI/Tests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)

// swift-tools-version: 5.9

import PackageDescription

#if TUIST
import ProjectDescription

let packageSettings = PackageSettings(
    productTypes: [
        "ViewEnvironmentUI": .framework,
        "ViewEnvironment": .framework,
        "Workflow": .framework,
        "WorkflowUI": .framework,
        "ReactiveSwift": .framework,
        "iOSSnapshotTestCase": .framework
    ],
    targetSettings: [
        "iOSSnapshotTestCase": ["ENABLE_TESTING_SEARCH_PATHS": "YES"]
    ]
)

#endif

let package = Package(
    name: "Development",
    dependencies: [
        .package(path: "../../"),
        .package(url: "https://github.com/uber/ios-snapshot-test-case.git", from: "8.0.0"),
    ]
)

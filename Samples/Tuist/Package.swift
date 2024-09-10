// swift-tools-version: 5.9

import PackageDescription

#if TUIST
import ProjectDescription

let unsuppressedWarningsSettings: SettingsDictionary = [
    "GCC_WARN_INHIBIT_ALL_WARNINGS": "$(inherited)",
    "SWIFT_SUPPRESS_WARNINGS": "$(inherited)",
]

let packageSettings = PackageSettings(
    productTypes: [
        "iOSSnapshotTestCase": .framework,
        "ReactiveSwift": .framework,
        "ViewEnvironment": .framework,
        "ViewEnvironmentUI": .framework,
        "Workflow": .framework,
        "WorkflowReactiveSwift": .framework,
        "WorkflowUI": .framework,
    ],
    targetSettings: [
        "iOSSnapshotTestCase": ["ENABLE_TESTING_SEARCH_PATHS": "YES"],
        "ViewEnvironment": unsuppressedWarningsSettings,
        "ViewEnvironmentUI": unsuppressedWarningsSettings,
        "Workflow": unsuppressedWarningsSettings,
        "WorkflowCombine": unsuppressedWarningsSettings,
        "WorkflowCombineTesting": unsuppressedWarningsSettings,
        "WorkflowConcurrency": unsuppressedWarningsSettings,
        "WorkflowConcurrencyTesting": unsuppressedWarningsSettings,
        "WorkflowReactiveSwift": unsuppressedWarningsSettings,
        "WorkflowReactiveSwiftTesting": unsuppressedWarningsSettings,
        "WorkflowRxSwift": unsuppressedWarningsSettings,
        "WorkflowRxSwiftTesting": unsuppressedWarningsSettings,
        "WorkflowSwiftUIExperimental": unsuppressedWarningsSettings,
        "WorkflowTesting": unsuppressedWarningsSettings,
        "WorkflowUI": unsuppressedWarningsSettings,
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

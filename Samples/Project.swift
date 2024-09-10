import Foundation
import ProjectDescription
import ProjectDescriptionHelpers

extension Target {
    static func snapshotTest(
        for moduleUnderTest: String,
        testName: String = "SnapshotTests",
        sources: ProjectDescription.SourceFilesList? = nil,
        dependencies: [TargetDependency] = []
    ) -> Self {
        .unitTest(
            for: moduleUnderTest,
            testName: testName,
            sources: sources,
            dependencies: dependencies,
            environmentVariables: snapshotEnvironment
        )
    }
}

let snapshotEnvironment: [String: EnvironmentVariable] = {
    let samplesPath = URL(filePath: #file)
        .deletingLastPathComponent()
        .path

    return [
        "FB_REFERENCE_IMAGE_DIR": .environmentVariable(
            value: "\(samplesPath)/SnapshotTests/ReferenceImages",
            isEnabled: true
        ),
        "IMAGE_DIFF_DIR": .environmentVariable(
            value: "\(samplesPath)/SnapshotTests/FailureDiffs",
            isEnabled: true
        ),
    ]
}()

let project = Project(
    name: "Development",
    settings: .settings(base: ["ENABLE_MODULE_VERIFIER": "YES"]),
    targets: [
        
        // MARK: - Samples

        .target(
            name: "AlertContainer",
            dependencies: [.external(name: "WorkflowUI")]
        ),

        .app(
            name: "AsyncWorker",
            sources: "AsyncWorker/Sources/**",
            dependencies: [
                .external(name: "WorkflowConcurrency"),
                .external(name: "WorkflowUI"),
            ]
        ),

        .target(
            name: "BackStackContainer",
            dependencies: [.external(name: "WorkflowUI")]
        ),

        .target(
            name: "ModalContainer",
            dependencies: [.external(name: "WorkflowUI")]
        ),

        .app(
            name: "ObservableScreen",
            sources: "ObservableScreen/Sources/**",
            dependencies: [.external(name: "WorkflowSwiftUI")]
        ),
        
        .app(
            name: "SampleApp",
            sources: "SampleApp/Sources/**",
            dependencies: [.external(name: "WorkflowUI")]
        ),
        
        .target(
            name: "SplitScreenContainer",
            dependencies: [.external(name: "WorkflowUI")]
        ),
        .app(
            name: "SplitScreenContainer-DemoApp",
            sources: "SplitScreenContainer/DemoApp/**",
            dependencies: [.target(name: "SplitScreenContainer")]
        ),
        .snapshotTest(
            for: "SplitScreenContainer",
            dependencies: [
                .target(name: "SplitScreenContainer"),
                .external(name: "iOSSnapshotTestCase"),
            ]
        ),
        
        .app(
            name: "TicTacToe",
            sources: "TicTacToe/Sources/**",
            dependencies: [
                .target(name: "AlertContainer"),
                .target(name: "BackStackContainer"),
                .target(name: "ModalContainer"),
            ]
        ),
        .unitTest(
            for: "TicTacToe",
            dependencies: [
                .target(name: "TicTacToe"),
                .external(name: "WorkflowReactiveSwiftTesting"),
                .external(name: "WorkflowTesting"),
            ]
        ),

        .app(
            name: "WorkflowCombineSampleApp",
            sources: "WorkflowCombineSampleApp/WorkflowCombineSampleApp/**",
            dependencies: [
                .external(name: "WorkflowCombine"),
                .external(name: "WorkflowUI"),
            ]
        ),
        .unitTest(
            for: "WorkflowCombineSampleApp",
            sources: "WorkflowCombineSampleApp/WorkflowCombineSampleAppUnitTests/**",
            dependencies: [
                .target(name: "WorkflowCombineSampleApp"),
                .external(name: "WorkflowTesting"),
            ]
        ),
        
        // MARK: - Workflow Tests

        // Some of these tests are duplicates of the test definitions in the root Package.swift, but Tuist
        // does not currently support creating targets for tests in SwiftPM dependencies. See
        // https://github.com/tuist/tuist/issues/5912

        .app(
            name: "TestAppHost",
            sources: "../TestingSupport/AppHost/Sources/**"
        ),

        .unitTest(
            for: "ViewEnvironmentUI",
            sources: "../ViewEnvironmentUI/Tests/**",
            dependencies: [
                .external(name: "ViewEnvironmentUI"),
                .target(name: "TestAppHost"),
            ]
        ),

        .unitTest(
            for: "Workflow",
            sources: "../Workflow/Tests/**",
            dependencies: [.external(name: "Workflow")]
        ),
        .unitTest(
            for: "WorkflowTesting",
            sources: "../WorkflowTesting/Tests/**",
            dependencies: [.external(name: "WorkflowTesting")]
        ),

        .unitTest(
            for: "WorkflowCombine",
            sources: "../WorkflowCombine/Tests/**",
            dependencies: [
                .external(name: "WorkflowCombine"),
                .external(name: "WorkflowCombineTesting"),
            ]
        ),
        .unitTest(
            for: "WorkflowCombineTesting",
            sources: "../WorkflowCombine/TestingTests/**",
            dependencies: [.external(name: "WorkflowCombineTesting")]
        ),

        .unitTest(
            for: "WorkflowConcurrency",
            sources: "../WorkflowConcurrency/Tests/**",
            dependencies: [.external(name: "WorkflowConcurrency")]
        ),
        .unitTest(
            for: "WorkflowConcurrencyTesting",
            sources: "../WorkflowConcurrency/TestingTests/**",
            dependencies: [.external(name: "WorkflowConcurrencyTesting")]
        ),

        .unitTest(
            for: "WorkflowReactiveSwift",
            sources: "../WorkflowReactiveSwift/Tests/**",
            dependencies: [.external(name: "WorkflowReactiveSwift")]
        ),
        .unitTest(
            for: "WorkflowReactiveSwiftTesting",
            sources: "../WorkflowReactiveSwift/TestingTests/**",
            dependencies: [.external(name: "WorkflowReactiveSwiftTesting")]
        ),

        .unitTest(
            for: "WorkflowRxSwift",
            sources: "../WorkflowRxSwift/Tests/**",
            dependencies: [.external(name: "WorkflowRxSwift")]
        ),
        .unitTest(
            for: "WorkflowRxSwiftTesting",
            sources: "../WorkflowRxSwift/TestingTests/**",
            dependencies: [.external(name: "WorkflowRxSwiftTesting")]
        ),

        .unitTest(
            for: "WorkflowSwiftUI",
            sources: "../WorkflowSwiftUI/Tests/**",
            dependencies: [.external(name: "WorkflowSwiftUI")]
        ),

        .unitTest(
            for: "WorkflowSwiftUIExperimental",
            sources: "../WorkflowSwiftUIExperimental/Tests/**",
            dependencies: [.external(name: "WorkflowSwiftUIExperimental")]
        ),

        // It's not currently possible to create a Tuist target that depends on a macro target. See
        // https://github.com/tuist/tuist/issues/5827, https://github.com/tuist/tuist/issues/6651,
        // and similar issues.

        // .unitTest(
        //     for: "WorkflowSwiftUIMacros",
        //     sources: "../WorkflowSwiftUIMacros/Tests/**",
        //     dependencies: [.external(name: "WorkflowSwiftUIMacros")]
        // ),

        .unitTest(
            for: "WorkflowUI",
            sources: "../WorkflowUI/Tests/**",
            dependencies: [
                .external(name: "WorkflowUI"),
                .external(name: "WorkflowReactiveSwift"),
                .target(name: "TestAppHost"),
            ]
        )
    ],
    schemes: [
        .scheme(
            name: "UnitTests",
            testAction: .targets(
                [
                    "TicTacToe-Tests",
                    "ViewEnvironmentUI-Tests",
                    "Workflow-Tests",
                    "WorkflowCombine-Tests",
                    "WorkflowCombineSampleApp-Tests",
                    "WorkflowCombineTesting-Tests",
                    "WorkflowConcurrency-Tests",
                    "WorkflowConcurrencyTesting-Tests",
                    "WorkflowReactiveSwift-Tests",
                    "WorkflowReactiveSwiftTesting-Tests",
                    "WorkflowRxSwift-Tests",
                    "WorkflowRxSwiftTesting-Tests",
                    "WorkflowSwiftUI-Tests",
                    "WorkflowSwiftUIExperimental-Tests",
                    "WorkflowTesting-Tests",
                    "WorkflowUI-Tests",
                ]
            )
        ),
        .scheme(
            name: "SnapshotTests",
            testAction: .targets(
                ["SplitScreenContainer-SnapshotTests"],
                arguments: .arguments(environmentVariables: snapshotEnvironment)
            )
        ),
    ]
)

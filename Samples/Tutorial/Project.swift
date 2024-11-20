import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "Tutorial",
    settings: .settings(base: ["ENABLE_MODULE_VERIFIER": "YES"]),
    targets: [
        .app(
            name: "Tutorial",
            sources: "AppHost/Sources/**",
            dependencies: [
                .target(name: "TutorialBase"),
                .target(name: "Tutorial1Complete"),
                .target(name: "Tutorial2Complete"),
                .target(name: "Tutorial3Complete"),
                .target(name: "Tutorial4Complete"),
                .target(name: "Tutorial5Complete"),
            ]
        ),

        .target(
            name: "Tutorial1Complete",
            sources: "Frameworks/Tutorial1Complete/Sources/**",
            dependencies: [
                .target(name: "TutorialViews"),
                .external(name: "WorkflowUI"),
                .external(name: "WorkflowReactiveSwift"),
                .project(target: "BackStackContainer", path: ".."),
            ]
        ),

        .target(
            name: "Tutorial2Complete",
            sources: "Frameworks/Tutorial2Complete/Sources/**",
            dependencies: [
                .target(name: "TutorialViews"),
                .external(name: "WorkflowUI"),
                .external(name: "WorkflowReactiveSwift"),
                .project(target: "BackStackContainer", path: ".."),
            ]
        ),

        .target(
            name: "Tutorial3Complete",
            sources: "Frameworks/Tutorial3Complete/Sources/**",
            dependencies: [
                .target(name: "TutorialViews"),
                .external(name: "WorkflowUI"),
                .external(name: "WorkflowReactiveSwift"),
                .project(target: "BackStackContainer", path: ".."),
            ]
        ),

        .target(
            name: "Tutorial4Complete",
            sources: "Frameworks/Tutorial4Complete/Sources/**",
            dependencies: [
                .target(name: "TutorialViews"),
                .external(name: "WorkflowUI"),
                .external(name: "WorkflowReactiveSwift"),
                .project(target: "BackStackContainer", path: ".."),
            ]
        ),
        .unitTest(
            for: "Tutorial4Complete",
            sources: "Frameworks/Tutorial4Complete/Tests/**",
            dependencies: [.target(name: "Tutorial4Complete")]
        ),

        .target(
            name: "Tutorial5Complete",
            sources: "Frameworks/Tutorial5Complete/Sources/**",
            dependencies: [
                .target(name: "TutorialViews"),
                .external(name: "WorkflowUI"),
                .external(name: "WorkflowReactiveSwift"),
                .project(target: "BackStackContainer", path: ".."),
            ]
        ),
        .unitTest(
            for: "Tutorial5Complete",
            sources: "Frameworks/Tutorial5Complete/Tests/**",
            dependencies: [
                .target(name: "Tutorial5Complete"),
                .external(name: "WorkflowTesting"),
            ]
        ),

        .target(
            name: "TutorialBase",
            sources: "Frameworks/TutorialBase/Sources/**",
            dependencies: [
                .target(name: "TutorialViews"),
                .external(name: "WorkflowUI"),
                .external(name: "WorkflowReactiveSwift"),
                .project(target: "BackStackContainer", path: ".."),
            ]
        ),
        .unitTest(
            for: "TutorialBase",
            sources: "Frameworks/TutorialBase/Tests/**"
        ),

        .target(
            name: "TutorialViews",
            sources: "Frameworks/TutorialViews/Sources/**"
        ),
    ],
    schemes: [
        .scheme(
            name: "TutorialTests",
            testAction: .targets(
                [
                    .testableTarget(target: .target("Tutorial4Complete-Tests")),
                    .testableTarget(target: .target("Tutorial5Complete-Tests")),
                    .testableTarget(target: .target("TutorialBase-Tests")),
                ]
            )
        ),
    ]
)

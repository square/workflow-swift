import ProjectDescription
import ProjectDescriptionHelpers

let workspace = Workspace(
    name: "Development",
    projects: [".", "Tutorial"],
    schemes: [
        // Generate a scheme for each target in Package.swift for convenience
        .workflow("Workflow"),
        .workflow("WorkflowTesting"),
        .workflow("WorkflowUI"),
        .workflow("WorkflowSwiftUI"),
        .workflow("WorkflowSwiftUIMacros"),
        .workflow("WorkflowReactiveSwift"),
        .workflow("WorkflowReactiveSwiftTesting"),
        .workflow("WorkflowRxSwift"),
        .workflow("WorkflowRxSwiftTesting"),
        .workflow("WorkflowCombine"),
        .workflow("WorkflowCombineTesting"),
        .workflow("WorkflowConcurrency"),
        .workflow("WorkflowConcurrencyTesting"),
        .workflow("ViewEnvironment"),
        .workflow("ViewEnvironmentUI"),
        .workflow("WorkflowSwiftUIExperimental"),
    ]
)

extension Scheme {
    public static func workflow(_ target: String) -> Self {
        .scheme(
            name: target,
            buildAction: .buildAction(targets: [.project(path: "..", target: target)])
        )
    }
}

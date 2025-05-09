import Foundation
import ProjectDescription

public let workflowBundleIdPrefix = "com.squareup.workflow"
public let workflowDestinations: ProjectDescription.Destinations = .iOS
public let workflowDeploymentTargets: DeploymentTargets = .iOS("16.0")

extension Target {
    public static func app(
        name: String,
        sources: ProjectDescription.SourceFilesList,
        resources: ProjectDescription.ResourceFileElements? = nil,
        dependencies: [TargetDependency] = []
    ) -> Self {
        .target(
            name: name,
            destinations: workflowDestinations,
            product: .app,
            bundleId: "\(workflowBundleIdPrefix).\(name)",
            deploymentTargets: workflowDeploymentTargets,
            infoPlist: .extendingDefault(
                with: [
                    "UILaunchScreen": ["UIColorName": ""],
                ]
            ),
            sources: sources,
            resources: resources,
            dependencies: dependencies
        )
    }

    public static func target(
        name: String,
        sources: ProjectDescription.SourceFilesList? = nil,
        resources: ProjectDescription.ResourceFileElements? = nil,
        dependencies: [TargetDependency] = []
    ) -> Self {
        .target(
            name: name,
            destinations: workflowDestinations,
            product: .framework,
            bundleId: "\(workflowBundleIdPrefix).\(name)",
            deploymentTargets: workflowDeploymentTargets,
            sources: sources ?? "\(name)/Sources/**",
            resources: resources,
            dependencies: dependencies
        )
    }

    public static func unitTest(
        for moduleUnderTest: String,
        testName: String = "Tests",
        sources: ProjectDescription.SourceFilesList? = nil,
        dependencies: [TargetDependency] = [],
        environmentVariables: [String: EnvironmentVariable] = [:]
    ) -> Self {
        let name = "\(moduleUnderTest)-\(testName)"
        return .target(
            name: name,
            destinations: workflowDestinations,
            product: .unitTests,
            bundleId: "\(workflowBundleIdPrefix).\(name)",
            deploymentTargets: workflowDeploymentTargets,
            sources: sources ?? "\(moduleUnderTest)/\(testName)/**",
            dependencies: dependencies,
            environmentVariables: environmentVariables
        )
    }
}

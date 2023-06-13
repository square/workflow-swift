#if canImport(UIKit)

import UIKit
import ViewEnvironment
import XCTest

@_spi(ViewEnvironmentWiring) @testable import ViewEnvironmentUI

final class ViewEnvironmentObservingTests: XCTestCase {
    // MARK: - Propagation

    func test_environment_propagation_to_child() {
        let child = TestViewEnvironmentObservingViewController()

        let container = TestViewEnvironmentObservingViewController(
            customizeEnvironment: { $0.testContext.number = 1 }
        )
        container.addChild(child)
        child.didMove(toParent: container)

        XCTAssertEqual(child.environment.testContext.number, 1)
    }

    func test_environment_propagation_to_presented() {
        let child = TestViewEnvironmentObservingViewController()

        let container = TestViewEnvironmentObservingViewController(
            customizeEnvironment: { $0.testContext.number = 1 }
        )

        // Needed for view controller presentation to function properly
        addToWindowMakingKeyAndVisible(container)

        container.present(child, animated: false, completion: {})

        XCTAssertEqual(child.environment.testContext.number, 1)
    }

    func test_environment_multiple_overrides_with_root() {
        var rootEnvironment: ViewEnvironment = .empty
        rootEnvironment.testContext.number = 1
        rootEnvironment.testContext.string = "Foo"
        rootEnvironment.testContext.bool = true

        let child = TestViewEnvironmentObservingViewController(
            customizeEnvironment: { $0.testContext.number = 2 }
        )

        let vanilla = UIViewController()
        vanilla.addChild(child)
        child.didMove(toParent: vanilla)

        let container = TestViewEnvironmentObservingViewController(
            customizeEnvironment: { $0.testContext.string = "Bar" }
        )
        container.addChild(vanilla)
        vanilla.didMove(toParent: container)

        let root = TestViewEnvironmentObservingViewController(
            customizeEnvironment: { $0.testContext.bool = false }
        )
        root.addChild(container)
        container.didMove(toParent: root)

        var expectedContext = rootEnvironment.testContext
        // Mutation by root
        expectedContext.bool = false
        // Mutation by container
        expectedContext.string = "Bar"
        // Mutation by child
        expectedContext.number = 2

        XCTAssertEqual(child.environment.testContext, expectedContext)
    }

    // MARK: - apply(environment:)

    func test_applyEnvironment() throws {
        let expectedRootEnvironment: ViewEnvironment = .empty

        var rootAppliedEnvironments: [ViewEnvironment] = []
        let root = TestViewEnvironmentObservingViewController(
            onApplyEnvironment: { rootAppliedEnvironments.append($0) }
        )

        var expectedChildEnvironment = expectedRootEnvironment
        let customizedChildNumber = 42
        expectedChildEnvironment.testContext.number = customizedChildNumber

        var childAppliedEnvironments: [ViewEnvironment] = []
        let child = TestViewEnvironmentObservingViewController(
            customizeEnvironment: { $0.testContext.number = customizedChildNumber },
            onApplyEnvironment: { childAppliedEnvironments.append($0) }
        )
        root.addChild(child)
        root.view.addSubview(child.view)
        child.didMove(toParent: root)

        XCTAssertTrue(rootAppliedEnvironments.isEmpty)
        XCTAssertTrue(childAppliedEnvironments.isEmpty)

        // needsEnvironmentUpdate should default to true
        XCTAssertTrue(root.needsEnvironmentUpdate)
        XCTAssertTrue(child.needsEnvironmentUpdate)

        // Ensure we have a window and trigger a layout pass at the root
        let window = addToWindowMakingKeyAndVisible(root)

        root.view.layoutIfNeeded()

        XCTAssertEqual(rootAppliedEnvironments.count, 1)
        XCTAssertEqual(childAppliedEnvironments.count, 1)
        do {
            let rootEnvironment = try XCTUnwrap(rootAppliedEnvironments.last)
            XCTAssertEqual(rootEnvironment.testContext, expectedRootEnvironment.testContext)

            let childEnvironment = try XCTUnwrap(childAppliedEnvironments.last)
            XCTAssertEqual(childEnvironment.testContext, expectedChildEnvironment.testContext)
        }

        XCTAssertFalse(root.needsEnvironmentUpdate)
        XCTAssertFalse(child.needsEnvironmentUpdate)

        // Flag the root for update so that both root and child receive a new application
        root.setNeedsEnvironmentUpdate()

        XCTAssertTrue(root.needsEnvironmentUpdate)
        XCTAssertTrue(child.needsEnvironmentUpdate)
        XCTAssertEqual(rootAppliedEnvironments.count, 1)
        XCTAssertEqual(childAppliedEnvironments.count, 1)

        root.view.layoutIfNeeded()

        XCTAssertEqual(rootAppliedEnvironments.count, 2)
        XCTAssertEqual(childAppliedEnvironments.count, 2)
        do {
            let rootEnvironment = try XCTUnwrap(rootAppliedEnvironments.last)
            XCTAssertEqual(rootEnvironment.testContext, expectedRootEnvironment.testContext)

            let childEnvironment = try XCTUnwrap(childAppliedEnvironments.last)
            XCTAssertEqual(childEnvironment.testContext, expectedChildEnvironment.testContext)
        }

        XCTAssertFalse(root.needsEnvironmentUpdate)
        XCTAssertFalse(child.needsEnvironmentUpdate)

        // Flag just the child for needing update
        child.setNeedsEnvironmentUpdate()

        XCTAssertFalse(root.needsEnvironmentUpdate)
        XCTAssertTrue(child.needsEnvironmentUpdate)
        XCTAssertEqual(rootAppliedEnvironments.count, 2)
        XCTAssertEqual(childAppliedEnvironments.count, 2)

        root.view.layoutIfNeeded()

        // Only the child should have been applied
        XCTAssertEqual(rootAppliedEnvironments.count, 2)
        XCTAssertEqual(childAppliedEnvironments.count, 3)
        XCTAssertFalse(root.needsEnvironmentUpdate)
        XCTAssertFalse(child.needsEnvironmentUpdate)
        do {
            let childEnvironment = try XCTUnwrap(childAppliedEnvironments.last)
            XCTAssertEqual(childEnvironment.testContext, expectedChildEnvironment.testContext)
        }

        window.resignKey()
    }

    // MARK: - environmentDidChange

    func test_environmentDidChange() {
        var rootEnvironmentDidChangeCallCount = 0
        let rootNode = ViewEnvironmentPropagationNode(
            environmentDidChange: { _ in
                rootEnvironmentDidChangeCallCount += 1
            }
        )
        XCTAssertEqual(rootEnvironmentDidChangeCallCount, 0)

        let viewController = UIViewController()
        rootNode.environmentDescendantsProvider = { [viewController] }

        // Setting an environmentDescendantsProvider on ViewEnvironmentPropagationNode triggers a
        // setNeedsEnvironmentUpdate()
        XCTAssertEqual(rootEnvironmentDidChangeCallCount, 1)

        viewController.environmentAncestorOverride = { [weak rootNode] in
            rootNode
        }

        var leafEnvironmentDidChangeCallCount = 0
        let leafNode = ViewEnvironmentPropagationNode(
            environmentAncestor:  { [weak viewController] in
                viewController
            },
            environmentDidChange: { _ in
                leafEnvironmentDidChangeCallCount += 1
            }
        )
        viewController.environmentDescendantsOverride = { [leafNode] }

        XCTAssertEqual(rootEnvironmentDidChangeCallCount, 1)
        XCTAssertEqual(leafEnvironmentDidChangeCallCount, 0)

        rootNode.setNeedsEnvironmentUpdate()

        XCTAssertEqual(rootEnvironmentDidChangeCallCount, 2)
        XCTAssertEqual(leafEnvironmentDidChangeCallCount, 1)
    }

    // MARK: - Overridden Flow

    func test_ancestor_customFlow() {
        let expectedTestContext: TestContext = .nonDefault

        let ancestor = TestViewEnvironmentObservingViewController(
            customizeEnvironment: { $0.testContext = expectedTestContext }
        )

        let viewController = UIViewController()
        viewController.environmentAncestorOverride = { ancestor }

        XCTAssertEqual(viewController.environment.testContext, expectedTestContext)
    }

    func test_descendant_customFlow() {
        let descendant = TestViewEnvironmentObservingViewController()
        
        let viewController = TestViewEnvironmentObservingViewController()
        viewController.environmentDescendantsOverride = { [descendant] }
        
        viewController.applyEnvironmentIfNeeded()
        descendant.applyEnvironmentIfNeeded()
        XCTAssertFalse(viewController.needsEnvironmentUpdate)
        XCTAssertFalse(descendant.needsEnvironmentUpdate)
        
        // With no ancestor configured the descendant should not respond to needing update
        viewController.setNeedsEnvironmentUpdate()
        XCTAssertTrue(viewController.needsEnvironmentUpdate)
        XCTAssertFalse(descendant.needsEnvironmentUpdate)
        
        // With an ancestor defined the VC should respond to needing update
        
        descendant.environmentAncestorOverride = { [weak viewController] in
            viewController
        }
        viewController.setNeedsEnvironmentUpdate()
        XCTAssertTrue(viewController.needsEnvironmentUpdate)
        XCTAssertTrue(descendant.needsEnvironmentUpdate)
    }

    func test_flowThroughDifferentNodeTypes() {
        let rootContext = TestContext()
        let expectedContext: TestContext = .nonDefault
        XCTAssertNotEqual(rootContext, expectedContext)

        let root = TestViewEnvironmentObservingViewController { $0.testContext = rootContext }
        let child = TestViewEnvironmentObservingViewController { $0.testContext.number = expectedContext.number }
        let node = ViewEnvironmentPropagationNode(
            environmentAncestor: { [weak root] in root },
            environmentDescendants: { [child] },
            customizeEnvironment: { $0.testContext.string = expectedContext.string }
        )
        child.environmentAncestorOverride = { node }
        root.environmentDescendantsOverride = { [node] }
        let descendant = TestViewEnvironmentObservingView { $0.testContext.bool = expectedContext.bool }
        child.environmentDescendantsOverride = { [descendant] }
        descendant.environmentAncestorOverride = { [weak child] in child }

        XCTAssertTrue(root.needsEnvironmentUpdate)
        XCTAssertTrue(child.needsEnvironmentUpdate)
        XCTAssertTrue(descendant.needsEnvironmentUpdate)

        root.applyEnvironmentIfNeeded()
        child.applyEnvironmentIfNeeded()
        descendant.applyEnvironmentIfNeeded()
        XCTAssertFalse(root.needsEnvironmentUpdate)
        XCTAssertFalse(child.needsEnvironmentUpdate)
        XCTAssertFalse(descendant.needsEnvironmentUpdate)

        root.setNeedsEnvironmentUpdate()
        XCTAssertTrue(root.needsEnvironmentUpdate)
        XCTAssertTrue(child.needsEnvironmentUpdate)
        XCTAssertTrue(descendant.needsEnvironmentUpdate)

        XCTAssertEqual(descendant.environment.testContext, expectedContext)
    }

    // MARK: - Observations

    func test_observation() throws {
        var expectedTestContext: TestContext = .nonDefault
        var observedEnvironments: [ViewEnvironment] = []

        let viewController = UIViewController()
        var observation: ViewEnvironmentUpdateObservationLifetime? = viewController
            .addEnvironmentNeedsUpdateObserver {
                observedEnvironments.append($0)
            }

        let container = TestViewEnvironmentObservingViewController(
            customizeEnvironment: { $0.testContext = expectedTestContext }
        )
        container.addChild(viewController)
        container.view.addSubview(viewController.view)
        viewController.didMove(toParent: container)

        XCTAssertEqual(observedEnvironments.count, 0)

        container.setNeedsEnvironmentUpdate()
        XCTAssertEqual(observedEnvironments.count, 1)
        XCTAssertEqual(expectedTestContext, observedEnvironments.last?.testContext)

        expectedTestContext.bool = !expectedTestContext.bool
        container.customizeEnvironment = { $0.testContext = expectedTestContext }
        container.setNeedsEnvironmentUpdate()
        XCTAssertEqual(observedEnvironments.count, 2)
        XCTAssertEqual(expectedTestContext, observedEnvironments.last?.testContext)

        _ = observation // Suppress warning about variable never being read
        observation = nil

        container.setNeedsEnvironmentUpdate()
        XCTAssertEqual(observedEnvironments.count, 2)
    }
}

// MARK: - Helpers

extension ViewEnvironmentObservingTests {
    @discardableResult
    fileprivate func addToWindowMakingKeyAndVisible(_ viewController: UIViewController) -> UIWindow {
        let window = UIWindow(
            frame: .init(
                origin: .zero,
                size: .init(
                    width: 600,
                    height: 600
                )
            )
        )
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        return window
    }

    fileprivate class TestViewEnvironmentObservingViewController: UIViewController, ViewEnvironmentObserving {
        var customizeEnvironment: (inout ViewEnvironment) -> Void
        var onApplyEnvironment: (ViewEnvironment) -> Void

        init(
            customizeEnvironment: @escaping (inout ViewEnvironment) -> Void = { _ in },
            onApplyEnvironment: @escaping (ViewEnvironment) -> Void = { _ in }
        ) {
            self.customizeEnvironment = customizeEnvironment
            self.onApplyEnvironment = onApplyEnvironment

            super.init(nibName: nil, bundle: nil)
        }

        func customize(environment: inout ViewEnvironment) {
            customizeEnvironment(&environment)
        }

        func apply(environment: ViewEnvironment) {
            onApplyEnvironment(environment)
        }

        override func viewWillLayoutSubviews() {
            super.viewWillLayoutSubviews()

            applyEnvironmentIfNeeded()
        }

        required init?(coder: NSCoder) { fatalError("") }
    }

    fileprivate class TestViewEnvironmentObservingView: UIView, ViewEnvironmentObserving {
        var customizeEnvironment: (inout ViewEnvironment) -> Void
        var onApplyEnvironment: (ViewEnvironment) -> Void

        init(
            customizeEnvironment: @escaping (inout ViewEnvironment) -> Void = { _ in },
            onApplyEnvironment: @escaping (ViewEnvironment) -> Void = { _ in }
        ) {
            self.customizeEnvironment = customizeEnvironment
            self.onApplyEnvironment = onApplyEnvironment

            super.init(frame: .zero)
        }

        func customize(environment: inout ViewEnvironment) {
            customizeEnvironment(&environment)
        }

        func apply(environment: ViewEnvironment) {
            onApplyEnvironment(environment)
        }

        override func layoutSubviews() {
            applyEnvironmentIfNeeded()

            super.layoutSubviews()
        }

        required init?(coder: NSCoder) { fatalError("") }
    }
}

#endif

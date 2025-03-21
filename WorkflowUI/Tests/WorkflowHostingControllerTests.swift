/*
 * Copyright 2020 Square Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#if canImport(UIKit)

import XCTest

import ReactiveSwift
import UIKit
import Workflow
import WorkflowReactiveSwift
@testable import WorkflowUI

fileprivate struct TestScreen: Screen {
    var string: String
    var onEnvironmentDidChange: ((ViewEnvironment) -> Void)?

    func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
        TestScreenViewController.description(for: self, environment: environment)
    }
}

fileprivate final class TestScreenViewController: ScreenViewController<TestScreen>, ViewEnvironmentObserving {
    var onScreenChange: (() -> Void)?

    override func screenDidChange(from previousScreen: TestScreen, previousEnvironment: ViewEnvironment) {
        super.screenDidChange(from: previousScreen, previousEnvironment: previousEnvironment)
        onScreenChange?()
    }

    func environmentDidChange() {
        screen.onEnvironmentDidChange?(environment)
    }
}

class WorkflowHostingControllerTests: XCTestCase {
    func test_initialization_renders_workflow() {
        let (signal, _) = Signal<Int, Never>.pipe()
        let workflow = SubscribingWorkflow(subscription: signal)
        let container = WorkflowHostingController(workflow: workflow)

        withExtendedLifetime(container) {
            let vc = container.rootViewController as! TestScreenViewController
            XCTAssertEqual("0", vc.screen.string)
        }
    }

    func test_workflow_update_causes_rerender() {
        let (signal, observer) = Signal<Int, Never>.pipe()
        let workflow = SubscribingWorkflow(subscription: signal)
        let container = WorkflowHostingController(workflow: workflow)

        withExtendedLifetime(container) {
            let expectation = XCTestExpectation(description: "View Controller updated")

            let vc = container.rootViewController as! TestScreenViewController
            vc.onScreenChange = {
                expectation.fulfill()
            }

            observer.send(value: 2)

            wait(for: [expectation], timeout: 1.0)

            XCTAssertEqual("2", vc.screen.string)
        }
    }

    func test_workflow_output_causes_container_output() {
        let (signal, observer) = Signal<Int, Never>.pipe()
        let workflow = SubscribingWorkflow(subscription: signal)
        let container = WorkflowHostingController(workflow: workflow)

        let expectation = XCTestExpectation(description: "Output")

        let disposable = container.output.observeValues { value in
            XCTAssertEqual(3, value)
            expectation.fulfill()
        }

        observer.send(value: 3)

        wait(for: [expectation], timeout: 1.0)

        disposable?.dispose()
    }

    func test_container_with_anyworkflow() {
        let (signal, observer) = Signal<Int, Never>.pipe()
        let workflow = SubscribingWorkflow(subscription: signal)
        let container = WorkflowHostingController(workflow: workflow.asAnyWorkflow())

        let expectation = XCTestExpectation(description: "Output")

        let disposable = container.output.observeValues { value in
            XCTAssertEqual(3, value)
            expectation.fulfill()
        }

        observer.send(value: 3)

        wait(for: [expectation], timeout: 1.0)

        disposable?.dispose()
    }

    func test_container_update_causes_rerender() {
        let firstWorkflow = PassthroughWorkflow(value: "first")
        let container = WorkflowHostingController(workflow: firstWorkflow)

        withExtendedLifetime(container) {
            let expectation = XCTestExpectation(description: "View Controller updated")

            let vc = container.rootViewController as! TestScreenViewController

            XCTAssertEqual("first", vc.screen.string)

            vc.onScreenChange = {
                expectation.fulfill()
            }

            let secondWorkflow = PassthroughWorkflow(value: "second")
            container.update(workflow: secondWorkflow)

            wait(for: [expectation], timeout: 1.0)

            XCTAssertEqual("second", vc.screen.string)
        }
    }

    func test_container_update_updates_output() {
        let firstWorkflow = EchoWorkflow(value: 1)
        let container = WorkflowHostingController(workflow: firstWorkflow)

        let expectation = XCTestExpectation(description: "Second output")

        // First output comes before we subscribe
        let disposable = container.output.observeValues { value in
            XCTAssertEqual(3, value)
            expectation.fulfill()
        }

        let secondWorkflow = EchoWorkflow(value: 3)
        container.update(workflow: secondWorkflow)

        wait(for: [expectation], timeout: 1.0)

        disposable?.dispose()
    }

    func test_environment_bridging() throws {
        struct WorkflowHostKey: ViewEnvironmentKey {
            static var defaultValue: Int = 0
        }
        struct ScreenKey: ViewEnvironmentKey {
            static var defaultValue: Bool = false
        }

        var changedEnvironments: [ViewEnvironment] = []
        let firstWorkflow = EnvironmentObservingWorkflow(
            value: "first",
            onEnvironmentDidChange: { env in
                changedEnvironments.append(env)
            }
        )
        let container = WorkflowHostingController(
            workflow: firstWorkflow
                .mapRendering {
                    $0.adaptedEnvironment(key: ScreenKey.self, value: true)
                },
            customizeEnvironment: { $0[WorkflowHostKey.self] = 1 }
        )

        // Expect a `setNeedsEnvironmentUpdate()` in the `ViewControllerDescription`'s build method and the
        // `container`'s initializer.
        XCTAssertEqual(changedEnvironments.count, 1)
        do {
            let environment = try XCTUnwrap(changedEnvironments.last)
            XCTAssertEqual(environment[WorkflowHostKey.self], 1)
            XCTAssertEqual(environment[ScreenKey.self], true)
        }

        // Test ancestor propagation
        struct AncestorKey: ViewEnvironmentKey {
            static var defaultValue: String = ""
        }

        let ancestorVC = EnvironmentCustomizingViewController { $0[AncestorKey.self] = "1" }
        ancestorVC.addChild(container)
        container.didMove(toParent: ancestorVC)
        XCTAssertEqual(changedEnvironments.count, 1)

        ancestorVC.setNeedsEnvironmentUpdate()
        XCTAssertEqual(changedEnvironments.count, 2)
        do {
            let environment = try XCTUnwrap(changedEnvironments.last)
            XCTAssertEqual(environment[AncestorKey.self], "1")
            XCTAssertEqual(environment[WorkflowHostKey.self], 1)
            XCTAssertEqual(environment[ScreenKey.self], true)
        }

        // Test an environment update. This does not implicitly trigger an environment update in this VC.
        ancestorVC.customizeEnvironment = { $0[AncestorKey.self] = "2" }
        // Updating customizeEnvironment on the WorkflowHostingController should trigger an environment update
        container.customizeEnvironment = { $0[WorkflowHostKey.self] = 2 }
        XCTAssertEqual(changedEnvironments.count, 3)
        do {
            let environment = try XCTUnwrap(changedEnvironments.last)
            XCTAssertEqual(environment[AncestorKey.self], "2")
            XCTAssertEqual(environment[WorkflowHostKey.self], 2)
            XCTAssertEqual(environment[ScreenKey.self], true)
        }
    }

    func test_environment_updates_on_layout_in_new_hierarchy() {
        var changedEnvironments: [ViewEnvironment] = []
        let hostingController = WorkflowHostingController(
            workflow: EnvironmentObservingWorkflow(
                value: "first",
                onEnvironmentDidChange: { changedEnvironments.append($0) }
            )
        )

        // Setup the initial hierarchy
        let root1 = UIViewController()
        let container = UIViewController()
        root1.addChild(container)
        root1.view.addSubview(container.view)
        container.didMove(toParent: root1)

        container.addChild(hostingController)
        container.view.addSubview(hostingController.view)
        hostingController.didMove(toParent: container)

        XCTAssertEqual(changedEnvironments.count, 1)

        // Triggering a layout should cause an update to the workflow's rendering since the
        // ancestor path has changed since the `WorkflowHostingController` was initialized
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        XCTAssertEqual(changedEnvironments.count, 2)

        // There should be no environment update if the Workflow state and ancestor tree path has
        // not changed
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        XCTAssertEqual(changedEnvironments.count, 2)

        // Change the environment ancestor path
        container.willMove(toParent: nil)
        container.view.removeFromSuperview()
        container.removeFromParent()

        let root2 = UIViewController()
        root2.addChild(container)
        root2.view.addSubview(container.view)
        container.didMove(toParent: root2)

        // An environment update should occur since the ancestor path has changed since the last
        // update and/or layout.
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        XCTAssertEqual(changedEnvironments.count, 3)

        // There should be no environment update if the Workflow state and ancestor tree path has
        // not changed
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        XCTAssertEqual(changedEnvironments.count, 3)
    }
}

fileprivate struct SubscribingWorkflow: Workflow {
    var subscription: Signal<Int, Never>

    typealias State = Int

    typealias Output = Int

    func makeInitialState() -> State {
        0
    }

    func render(state: State, context: RenderContext<Self>) -> TestScreen {
        subscription
            .mapOutput { output in
                AnyWorkflowAction { state, _ in
                    state = output
                    return output
                }
            }.running(in: context, key: "signal")

        return TestScreen(string: "\(state)")
    }
}

fileprivate struct PassthroughWorkflow: Workflow {
    var value: String

    typealias State = Void

    typealias Output = Never

    func render(state: State, context: RenderContext<Self>) -> TestScreen {
        TestScreen(string: value)
    }
}

fileprivate struct EchoWorkflow: Workflow {
    var value: Int

    typealias State = Void

    typealias Output = Int

    struct EchoWorker: Worker {
        var value: Int

        func run() -> SignalProducer<Int, Never> {
            SignalProducer(value: value)
        }

        func isEquivalent(to otherWorker: Self) -> Bool {
            value == otherWorker.value
        }
    }

    func render(state: State, context: RenderContext<Self>) -> TestScreen {
        EchoWorker(value: value)
            .mapOutput { AnyWorkflowAction(sendingOutput: $0) }
            .running(in: context)
        return TestScreen(string: "\(value)")
    }
}

fileprivate struct EnvironmentObservingWorkflow: Workflow {
    var value: String
    var onEnvironmentDidChange: (ViewEnvironment) -> Void

    typealias State = Void

    typealias Output = Never

    func render(state: State, context: RenderContext<Self>) -> TestScreen {
        TestScreen(string: value, onEnvironmentDidChange: onEnvironmentDidChange)
    }
}

fileprivate final class EnvironmentCustomizingViewController: UIViewController, ViewEnvironmentObserving {
    var customizeEnvironment: (inout ViewEnvironment) -> Void

    init(customizeEnvironment: @escaping (inout ViewEnvironment) -> Void) {
        self.customizeEnvironment = customizeEnvironment
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func customize(environment: inout ViewEnvironment) {
        customizeEnvironment(&environment)
    }
}

#endif

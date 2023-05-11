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
import Workflow
import WorkflowReactiveSwift
@testable import WorkflowUI

fileprivate struct TestScreen: Screen {
    var string: String
    var onEnvironmentDidChange: ((ViewEnvironment) -> Void)?

    func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
        return TestScreenViewController.description(for: self, environment: environment)
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
        struct WorkflowHostKeyKey: ViewEnvironmentKey {
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
            customizeEnvironment: { $0[WorkflowHostKeyKey.self] = 1 }
        )

        // Expect a `setNeedsEnvironmentUpdate()` in the `ViewControllerDescription`'s build method and the
        // `container`'s initializer.
        XCTAssertEqual(changedEnvironments.count, 1)
        do {
            let environment = try XCTUnwrap(changedEnvironments.last)
            XCTAssertEqual(environment[WorkflowHostKeyKey.self], 1)
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
            XCTAssertEqual(environment[WorkflowHostKeyKey.self], 1)
            XCTAssertEqual(environment[ScreenKey.self], true)
        }

        // Test an environment update. This does not implicitly trigger an environment update in this VC.
        ancestorVC.customizeEnvironment = { $0[AncestorKey.self] = "2" }
        // Updating customizeEnvironment on the WorkflowHostingController should trigger an environment update
        container.customizeEnvironment = { $0[WorkflowHostKeyKey.self] = 2 }
        XCTAssertEqual(changedEnvironments.count, 3)
        do {
            let environment = try XCTUnwrap(changedEnvironments.last)
            XCTAssertEqual(environment[AncestorKey.self], "2")
            XCTAssertEqual(environment[WorkflowHostKeyKey.self], 2)
            XCTAssertEqual(environment[ScreenKey.self], true)
        }
    }
}

fileprivate struct SubscribingWorkflow: Workflow {
    var subscription: Signal<Int, Never>

    typealias State = Int

    typealias Output = Int

    func makeInitialState() -> State {
        return 0
    }

    func render(state: State, context: RenderContext<Self>) -> TestScreen {
        subscription
            .mapOutput { output in
                AnyWorkflowAction { state in
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
        return TestScreen(string: value)
    }
}

fileprivate struct EchoWorkflow: Workflow {
    var value: Int

    typealias State = Void

    typealias Output = Int

    struct EchoWorker: Worker {
        var value: Int

        func run() -> SignalProducer<Int, Never> {
            return SignalProducer(value: value)
        }

        func isEquivalent(to otherWorker: Self) -> Bool {
            return value == otherWorker.value
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
        return TestScreen(string: value, onEnvironmentDidChange: onEnvironmentDidChange)
    }
}

fileprivate final class EnvironmentCustomizingViewController: UIViewController, ViewEnvironmentObserving {

    var customizeEnvironment: (inout ViewEnvironment) -> Void

    init(customizeEnvironment: @escaping (inout ViewEnvironment) -> Void) {
        self.customizeEnvironment = customizeEnvironment
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    func customize(environment: inout ViewEnvironment) {
        customizeEnvironment(&environment)
    }
}

#endif

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
import WorkflowUIReactiveSwift
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

class WorkflowHostingControllerOutputTests: XCTestCase {
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
                AnyWorkflowAction { state in
                    state = output
                    return output
                }
            }.running(in: context, key: "signal")

        return TestScreen(string: "\(state)")
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

#endif

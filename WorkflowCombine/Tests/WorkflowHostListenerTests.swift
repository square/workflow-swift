/*
 * Copyright 2022 Square Inc.
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

import Combine
import Foundation
import Workflow
import XCTest
@testable import WorkflowCombine

class WorkflowHostListenerTests: XCTestCase {
    func test_addingPublisherRenderingListener() {
        let host = WorkflowHost(workflow: TestWorkflow(step: .first))

        let renderingsComplete = expectation(description: "Waiting for renderings")
        let cancellable = host.renderingPublisher.sink { rendering in
            XCTAssertEqual(2, host.rendering)
            renderingsComplete.fulfill()
        }

        host.update(workflow: TestWorkflow(step: .second))

        waitForExpectations(timeout: 1)
        cancellable.cancel()
    }

    func test_addingPublisherOutputListener() {
        let host = WorkflowHost(workflow: TestOutputWorkflow(state: 0))

        let outputComplete = expectation(description: "Waiting for output")
        let cancellable = host.outputPublisher.sink { output in
            XCTAssertEqual(1, output)
            outputComplete.fulfill()
        }

        host.rendering.onIncrement()

        waitForExpectations(timeout: 1)
        cancellable.cancel()
    }

    fileprivate struct TestWorkflow: Workflow {
        var step: Step
        enum Step {
            case first
            case second
        }

        struct State {}
        func makeInitialState() -> State {
            return State()
        }

        typealias Rendering = Int

        func render(state: State, context: RenderContext<TestWorkflow>) -> Rendering {
            switch step {
            case .first:
                return 1
            case .second:
                return 2
            }
        }
    }

    fileprivate struct IncrementAction: WorkflowAction {
        typealias WorkflowType = TestOutputWorkflow

        let value: Int

        func apply(toState state: inout Int) -> TestOutputWorkflow.Output? {
            state += value
            return state
        }
    }

    fileprivate struct TestOutputRendering {
        let onIncrement: () -> Void
    }

    fileprivate struct TestOutputWorkflow: Workflow {
        func makeInitialState() -> State {
            return 0
        }

        typealias Rendering = TestOutputRendering
        typealias Output = Int
        typealias State = Int

        var state: State

        func render(state: State, context: RenderContext<TestOutputWorkflow>) -> Rendering {
            let sink = context.makeSink(of: IncrementAction.self)
            return TestOutputRendering {
                sink.send(IncrementAction(value: 1))
            }
        }
    }
}

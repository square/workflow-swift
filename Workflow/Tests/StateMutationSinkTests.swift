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

import ReactiveSwift
import Workflow
import XCTest

final class StateMutationSinkTests: XCTestCase {
    var output: Signal<Int, Never>!
    var input: Signal<Int, Never>.Observer!

    override func setUp() {
        (output, input) = Signal<Int, Never>.pipe()
    }

    func test_initialValue() {
        let host = WorkflowHost(workflow: TestWorkflow(value: 100, signal: output))
        XCTAssertEqual(0, host.rendering.value)
    }

    func test_singleUpdate() {
        let host = WorkflowHost(workflow: TestWorkflow(value: 100, signal: output))

        let gotValueExpectation = expectation(description: "Got expected value")
        host.rendering.producer.startWithValues { val in
            if val == 100 {
                gotValueExpectation.fulfill()
            }
        }

        input.send(value: 100)
        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_multipleUpdates() {
        let host = WorkflowHost(workflow: TestWorkflow(value: 100, signal: output))

        let gotValueExpectation = expectation(description: "Got expected value")

        var values: [Int] = []
        host.rendering.producer.startWithValues { val in
            values.append(val)
            if val == 300 {
                gotValueExpectation.fulfill()
            }
        }

        input.send(value: 100)
        input.send(value: 200)
        input.send(value: 300)
        XCTAssertEqual(values, [0, 100, 200, 300])
        waitForExpectations(timeout: 1, handler: nil)
    }

    fileprivate struct TestWorkflow: Workflow {
        typealias State = Int
        typealias Rendering = Int

        let value: Int
        let signal: Signal<Int, Never>

        func makeInitialState() -> Int {
            0
        }

        func render(state: State, context: RenderContext<TestWorkflow>) -> Rendering {
            let stateMutationSink = context.makeStateMutationSink()
            context.runSideEffect(key: "") { lifetime in
                let disposable = signal.observeValues { val in
                    stateMutationSink.send(\State.self, value: val)
                }
                lifetime.onEnded {
                    disposable?.dispose()
                }
            }
            return state
        }
    }
}

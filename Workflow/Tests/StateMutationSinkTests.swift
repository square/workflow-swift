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
import Workflow
import XCTest

@MainActor
final class StateMutationSinkTests: XCTestCase {
    var input: PassthroughSubject<Int, Never>!

    override func setUp() {
        input = PassthroughSubject()
    }

    func test_initialValue() {
        let host = WorkflowHost(workflow: TestWorkflow(value: 100, publisher: input.eraseToAnyPublisher()))
        XCTAssertEqual(0, host.rendering)
    }

    func test_singleUpdate() {
        let host = WorkflowHost(workflow: TestWorkflow(value: 100, publisher: input.eraseToAnyPublisher()))

        let gotValueExpectation = expectation(description: "Got expected value")
        let cancellable = host.renderingPublisher.dropFirst().sink { val in
            if val == 100 {
                gotValueExpectation.fulfill()
            }
        }
        defer { cancellable.cancel() }

        input.send(100)
        waitForExpectations(timeout: 1, handler: nil)
    }

    func test_multipleUpdates() {
        let host = WorkflowHost(workflow: TestWorkflow(value: 100, publisher: input.eraseToAnyPublisher()))

        let gotValueExpectation = expectation(description: "Got expected value")

        var values: [Int] = []
        let cancellable = host.renderingPublisher.dropFirst().sink { val in
            values.append(val)
            if val == 300 {
                gotValueExpectation.fulfill()
            }
        }
        defer { cancellable.cancel() }

        input.send(100)
        input.send(200)
        input.send(300)
        XCTAssertEqual(values, [100, 200, 300])
        waitForExpectations(timeout: 1, handler: nil)
    }

    fileprivate struct TestWorkflow: Workflow {
        typealias State = Int
        typealias Rendering = Int

        let value: Int
        let publisher: AnyPublisher<Int, Never>

        func makeInitialState() -> Int {
            0
        }

        func render(state: State, context: RenderContext<TestWorkflow>) -> Rendering {
            let stateMutationSink = context.makeStateMutationSink()
            context.runSideEffect(key: "") { lifetime in
                let cancellable = publisher.sink { val in
                    stateMutationSink.send(\State.self, value: val)
                }
                lifetime.onEnded {
                    cancellable.cancel()
                }
            }
            return state
        }
    }
}

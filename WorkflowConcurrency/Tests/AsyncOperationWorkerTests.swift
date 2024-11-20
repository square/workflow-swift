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

import Workflow
import WorkflowTesting
import XCTest
@testable import WorkflowConcurrency

final class AsyncOperationWorkerTests: XCTestCase {
    func testWorkerOutput() {
        let host = WorkflowHost(
            workflow: TestAsyncOperationWorkerWorkflow(key: "")
        )

        let expectation = XCTestExpectation()
        let disposable = host.rendering.signal.observeValues { rendering in
            expectation.fulfill()
        }

        XCTAssertEqual(0, host.rendering.value)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(1, host.rendering.value)

        disposable?.dispose()
    }

    func testAsyncWorkerRunsOnlyOnce() {
        let host = WorkflowHost(
            workflow: TestAsyncOperationWorkerWorkflow(key: "")
        )

        var expectation = XCTestExpectation()
        var disposable = host.rendering.signal.observeValues { rendering in
            expectation.fulfill()
        }

        XCTAssertEqual(0, host.rendering.value)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(1, host.rendering.value)

        disposable?.dispose()

        expectation = XCTestExpectation()
        disposable = host.rendering.signal.observeValues { rendering in
            expectation.fulfill()
        }

        // Trigger a render
        host.update(workflow: TestAsyncOperationWorkerWorkflow(key: ""))

        wait(for: [expectation], timeout: 1.0)
        // If the render value is 1 then the state has not been incremented
        // by running the worker's async operation again.
        XCTAssertEqual(1, host.rendering.value)

        disposable?.dispose()
    }

    func testCancelAsyncOperationWorker() {
        struct WorkerWorkflow: Workflow {
            typealias State = Void

            enum Mode {
                case notWorking
                case working(start: XCTestExpectation, end: XCTestExpectation)
            }

            let mode: Mode

            func render(state: State, context: RenderContext<WorkerWorkflow>) -> Bool {
                switch mode {
                case .notWorking:
                    return false
                case .working(start: let startExpectation, end: let endExpectation):
                    AsyncOperationWorker {
                        await asyncOperation(startExpectation: startExpectation, endExpectation: endExpectation)
                    }
                    .mapOutput { _ in AnyWorkflowAction.noAction }
                    .running(in: context)
                    return true
                }
            }

            func asyncOperation(startExpectation: XCTestExpectation, endExpectation: XCTestExpectation) async {
                startExpectation.fulfill()
                for _ in 1 ... 200 {
                    if Task.isCancelled {
                        endExpectation.fulfill()
                        return
                    }
                    try? await Task.sleep(nanoseconds: 10000000)
                }
                endExpectation.fulfill()
            }
        }

        let startExpectation = XCTestExpectation()
        let endExpectation = XCTestExpectation()
        let host = WorkflowHost(
            workflow: WorkerWorkflow(mode: .working(
                start: startExpectation,
                end: endExpectation
            ))
        )

        wait(for: [startExpectation], timeout: 1.0)

        host.update(workflow: WorkerWorkflow(mode: .notWorking))

        wait(for: [endExpectation], timeout: 1.0)
    }
}

private struct TestAsyncOperationWorkerWorkflow: Workflow {
    typealias State = Int
    typealias Rendering = Int

    let key: String

    func makeInitialState() -> Int { 0 }

    func render(state: Int, context: RenderContext<TestAsyncOperationWorkerWorkflow>) -> Int {
        AsyncOperationWorker(outputOne)
            .mapOutput { output in
                AnyWorkflowAction { state in
                    state += output
                    return nil
                }
            }
            .running(in: context, key: key)
        return state
    }

    func outputOne() async -> Int {
        1
    }
}

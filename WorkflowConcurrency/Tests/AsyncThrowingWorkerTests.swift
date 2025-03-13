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

final class AsyncThrowingWorkerTests: XCTestCase {
    func testWorkerOutput() {
        let host = WorkflowHost(
            workflow: TestAsyncThrowingWorkerWorkflow(key: "", shouldThrowError: false)
        )

        let expectation = XCTestExpectation()
        let disposable = host.rendering.signal.observeValues { rendering in
            expectation.fulfill()
        }

        XCTAssertEqual(0, try! host.rendering.value.get())

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(1, try! host.rendering.value.get())

        disposable?.dispose()
    }

    func testWorkerThrows() {
        let host = WorkflowHost(
            workflow: TestAsyncThrowingWorkerWorkflow(key: "", shouldThrowError: true)
        )

        let expectation = XCTestExpectation()
        let disposable = host.rendering.signal.observeValues { rendering in
            expectation.fulfill()
        }

        XCTAssertEqual(0, try! host.rendering.value.get())

        wait(for: [expectation], timeout: 1.0)

        XCTAssertThrowsError(try host.rendering.value.get()) { error in
            XCTAssertTrue(error is TestAsyncThrowingWorkerError)
        }

        disposable?.dispose()
    }

    func testAsyncWorkerRunsOnlyOnce() {
        let host = WorkflowHost(
            workflow: TestAsyncThrowingWorkerWorkflow(key: "", shouldThrowError: false)
        )

        var expectation = XCTestExpectation()
        var disposable = host.rendering.signal.observeValues { rendering in
            expectation.fulfill()
        }

        XCTAssertEqual(0, try! host.rendering.value.get())

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(1, try! host.rendering.value.get())

        disposable?.dispose()

        expectation = XCTestExpectation()
        disposable = host.rendering.signal.observeValues { rendering in
            expectation.fulfill()
        }

        // Trigger a render
        host.update(workflow: TestAsyncThrowingWorkerWorkflow(key: "", shouldThrowError: false))

        wait(for: [expectation], timeout: 1.0)
        // If the render value is 1 then the state has not been incremented
        // by running the worker's async operation again.
        XCTAssertEqual(1, try! host.rendering.value.get())

        disposable?.dispose()
    }

    func testCancelAsyncThrowingWorker() {
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
                    AsyncThrowingWorker {
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

private struct TestAsyncThrowingWorkerError: Error {}

private struct TestAsyncThrowingWorkerWorkflow: Workflow {
    typealias State = Result<Int, Error>
    typealias Rendering = Result<Int, Error>

    let key: String
    let shouldThrowError: Bool

    func makeInitialState() -> State { .success(0) }

    func render(state: State, context: RenderContext<TestAsyncThrowingWorkerWorkflow>) -> Rendering {
        let function = shouldThrowError ? throwError : outputOne

        context.run {
            let output = try await function()
            return AnyWorkflowAction { state in
                state = .success(output)
                return nil
            }
        } catch: { error in
            AnyWorkflowAction { state in
                state = .failure(error)
                return nil
            }
        }

        return state
    }

    func outputOne() async throws -> Int {
        1
    }

    func throwError() async throws -> Int {
        throw TestAsyncThrowingWorkerError()
    }
}

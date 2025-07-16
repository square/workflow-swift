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

import Workflow
import WorkflowTesting
import XCTest
@testable import WorkflowConcurrency

class WorkerTests: XCTestCase {
    func testWorkerOutput() {
        let host = WorkflowHost(
            workflow: TaskTestWorkerWorkflow(key: "", initialState: 0)
        )

        let expectation = XCTestExpectation()
        let cancellable = host.rendering.dropFirst().sink { _ in
            expectation.fulfill()
        }

        XCTAssertEqual(0, host.rendering.value)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(1, host.rendering.value)

        cancellable.cancel()
    }

    func testWorkflowUpdate() {
        // Create the workflow which causes the TaskTestWorker to run.
        let host = WorkflowHost(
            workflow: TaskTestWorkerWorkflow(key: "", initialState: 0)
        )

        var expectation = XCTestExpectation()
        // Set to observe renderings
        // This expectation should be called after the TaskTestWorker runs and
        // updates the state.
        var cancellable = host.rendering.dropFirst().sink { _ in
            expectation.fulfill()
        }

        // Test to make sure the initial state of the workflow is correct.
        XCTAssertEqual(0, host.rendering.value)

        // Wait for the worker to run.
        wait(for: [expectation], timeout: 1.0)
        // Test to make sure the rendering after the worker runs is correct.
        XCTAssertEqual(1, host.rendering.value)

        cancellable.cancel()

        expectation = XCTestExpectation()
        // Set to observe renderings
        // This expectation should be called after the workflow is updated.
        // After the host is updated with a new workflow instance the
        // initial state should be 1.
        cancellable = host.rendering.dropFirst().sink { _ in
            expectation.fulfill()
        }

        // Updated the workflow to a new initial state.
        host.update(workflow: TaskTestWorkerWorkflow(key: "", initialState: 7))

        // Wait for the workflow to render after being updated.
        wait(for: [expectation], timeout: 1.0)
        // Test to make sure the rendering matches the initial state.
        XCTAssertEqual(7, host.rendering.value)

        cancellable.cancel()

        expectation = XCTestExpectation()
        // Set to observe renderings
        // This expectation should be called when the worker runs.
        // The worker isEquivalent is false because we have changed the initialState.
        cancellable = host.rendering.dropFirst().sink { _ in
            expectation.fulfill()
        }

        // Wait for the worker to trigger a rendering.
        wait(for: [expectation], timeout: 1.0)
        // Check to make sure the rendering is correct.
        XCTAssertEqual(8, host.rendering.value)
    }

    func testWorkflowKeyChange() {
        // Create the workflow which causes the TaskTestWorker to run.
        let host = WorkflowHost(
            workflow: TaskTestWorkerWorkflow(key: "", initialState: 0)
        )

        var expectation = XCTestExpectation()
        // Set to observe renderings
        // This expectation should be called after the TaskTestWorker runs and
        // updates the state.
        var cancellable = host.rendering.dropFirst().sink { _ in
            expectation.fulfill()
        }

        // Test to make sure the initial state of the workflow is correct.
        XCTAssertEqual(0, host.rendering.value)

        // Wait for the worker to run.
        wait(for: [expectation], timeout: 1.0)
        // Test to make sure the rendering after the worker runs is correct.
        XCTAssertEqual(1, host.rendering.value)

        cancellable.cancel()

        expectation = XCTestExpectation()
        // Set to observe renderings
        // This expectation should be called after the workflow is updated.
        // After the host is updated with a new workflow instance the
        // initial state should be 1.
        cancellable = host.rendering.dropFirst().sink { _ in
            expectation.fulfill()
        }

        // Update the workflow to a new key which should force the worker to run.
        host.update(workflow: TaskTestWorkerWorkflow(key: "key", initialState: 0))

        // Wait for the workflow to render after being updated.
        wait(for: [expectation], timeout: 1.0)
        // Test to make sure the rendering matches the existing state
        // since the inititalState didn't change.
        XCTAssertEqual(1, host.rendering.value)

        expectation = XCTestExpectation()
        // Set to observe renderings
        // This expectation should be called when the worker runs.
        // The worker should run because the key was changed for the workflow.
        cancellable = host.rendering.dropFirst().sink { _ in
            expectation.fulfill()
        }

        // Wait for the worker to trigger a rendering.
        wait(for: [expectation], timeout: 1.0)
        // Check to make sure the rendering is correct.
        // The worker adds one to the initialState so this should be 1.
        XCTAssertEqual(1, host.rendering.value)
    }

    func testExpectedWorker() {
        TaskTestWorkerWorkflow(key: "123", initialState: 0)
            .renderTester()
            .expectWorkflow(
                type: WorkerWorkflow<TaskTestWorker>.self,
                key: "123",
                producingRendering: (),
                producingOutput: 1,
                assertions: { _ in }
            )
            .render { _ in }
            .verifyState { state in
                XCTAssertEqual(state, 1)
            }
    }

    // A worker declared on a first `render` pass that is not on a subsequent should have the work cancelled.
    func test_cancelsWorkers() {
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
                    ExpectingWorker(
                        startExpectation: startExpectation,
                        endExpectation: endExpectation
                    )
                    .mapOutput { _ in AnyWorkflowAction.noAction }
                    .running(in: context)
                    return true
                }
            }

            struct ExpectingWorker: Worker {
                typealias Output = Void

                let startExpectation: XCTestExpectation
                let endExpectation: XCTestExpectation

                func run() async {
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

                func isEquivalent(to otherWorker: WorkerWorkflow.ExpectingWorker) -> Bool {
                    true
                }
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

private struct TaskTestWorkerWorkflow: Workflow {
    typealias State = Int
    typealias Rendering = Int

    let key: String
    let initialState: Int
    func makeInitialState() -> Int { initialState }

    func render(state: Int, context: RenderContext<TaskTestWorkerWorkflow>) -> Int {
        TaskTestWorker(initialState: initialState)
            .mapOutput { output in
                AnyWorkflowAction { state in
                    state = output
                    return nil
                }
            }
            .running(in: context, key: key)
        return state
    }

    func workflowDidChange(from previousWorkflow: TaskTestWorkerWorkflow, state: inout Int) {
        if previousWorkflow.initialState != initialState {
            state = initialState
        }
    }
}

private struct TaskTestWorker: Worker {
    typealias Output = Int
    let initialState: Int

    func run() async -> Int {
        do {
            try await Task.sleep(nanoseconds: 10000000)
        } catch {}

        return initialState + 1
    }

    func isEquivalent(to otherWorker: TaskTestWorker) -> Bool {
        otherWorker.initialState == initialState
    }
}

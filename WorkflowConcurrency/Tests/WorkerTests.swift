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

@available(iOS 13.0, macOS 10.15, *)
class WorkerTests: XCTestCase {
    func testTaskOutput() {
        let host = WorkflowHost(
            workflow: TaskTestWorkflow(key: "")
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

    func testWorkerOutput() {
        let host = WorkflowHost(
            workflow: TaskTestWorkerWorkflow(key: "")
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

    func testExpectedWorker() {
        TaskTestWorkerWorkflow(key: "123")
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

                func run() async -> Void {
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

@available(iOS 13.0, macOS 10.15, *)
private struct TaskTestWorkflow: Workflow {
    typealias State = Int
    typealias Rendering = Int

    let key: String

    func makeInitialState() -> Int { 0 }

    func render(state: Int, context: RenderContext<TaskTestWorkflow>) -> Int {
        Task { () -> AnyWorkflowAction in
            do {
                try await Task.sleep(nanoseconds: 10000000)
            } catch {}

            return AnyWorkflowAction { state in
                state = 1
                return nil
            }
        }
        .running(in: context, key: key)
        return state
    }
}

@available(iOS 13.0, macOS 10.15, *)
private struct TaskTestWorkerWorkflow: Workflow {
    typealias State = Int
    typealias Rendering = Int

    let key: String

    func makeInitialState() -> Int { 0 }

    func render(state: Int, context: RenderContext<TaskTestWorkerWorkflow>) -> Int {
        TaskTestWorker()
            .mapOutput { output in
                AnyWorkflowAction { state in
                    state = output
                    return nil
                }
            }
            .running(in: context, key: key)
        return state
    }
}

@available(iOS 13.0, macOS 10.15, *)
private struct TaskTestWorker: Worker {
    typealias Output = Int

    func run() async -> Int {
        do {
            try await Task.sleep(nanoseconds: 10000000)
        } catch {}

        return 1
    }

    func isEquivalent(to otherWorker: TaskTestWorker) -> Bool { true }
}

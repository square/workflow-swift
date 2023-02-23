//
//  AsyncStreamWorkerTests.swift
//
//
//  Created by Mark Johnson on 9/1/22.
//

import Workflow
import WorkflowTesting
import XCTest
@testable import WorkflowConcurrency

class AsyncStreamWorkerTests: XCTestCase {
    func testWorkerOutput() {
        let host = WorkflowHost(
            workflow: TestAsyncStreamWorkerWorkflow(key: "")
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
        TestAsyncStreamWorkerWorkflow(key: "123")
            .renderTester()
            .expectWorkflow(
                type: AsyncStreamWorkerWorkflow<IntWorker>.self,
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

            struct ExpectingWorker: AsyncStreamWorker {
                typealias Output = Void

                let startExpectation: XCTestExpectation
                let endExpectation: XCTestExpectation

                func run() -> AsyncStream<Output> {
                    startExpectation.fulfill()
                    return AsyncStream<Output> {
                        if Task.isCancelled {
                            endExpectation.fulfill()
                            return nil
                        }
                        return ()
                    }
                    onCancel: { @Sendable() in endExpectation.fulfill() }
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

    private struct TestAsyncStreamWorkerWorkflow: Workflow {
        typealias State = Int
        typealias Rendering = Int

        let key: String

        func makeInitialState() -> Int { 0 }

        func render(state: Int, context: RenderContext<Self>) -> Int {
            IntWorker()
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

    struct IntWorker: AsyncStreamWorker {
        func run() -> AsyncStream<Int> {
            var i = 0
            return AsyncStream<Int> {
                i += 1
                return i
            }
            onCancel: { @Sendable() in print("Canceled.") }
        }

        func isEquivalent(to otherWorker: IntWorker) -> Bool {
            true
        }

        typealias Output = Int
    }
}

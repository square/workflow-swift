import Workflow
import WorkflowTesting
import XCTest
@testable import WorkflowConcurrency

class AsyncSequenceWorkerTests: XCTestCase {
    func testWorkerOutput() {
        let host = WorkflowHost(
            workflow: TestIntWorkerWorkflow(key: "", isEquivalent: true)
        )

        let expectation = XCTestExpectation()
        let disposable = host.rendering.signal.observeValues { rendering in
            expectation.fulfill()
        }

        XCTAssertEqual(0, host.rendering.value.intValue)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(1, host.rendering.value.intValue)

        disposable?.dispose()
    }

    func testNotEquivalentWorker() {
        // Create the workflow which causes the IntWorker to run.
        let host = WorkflowHost(
            workflow: TestIntWorkerWorkflow(key: "", isEquivalent: false)
        )

        var expectation = XCTestExpectation()
        // Set to observe renderings.
        // This expectation should be called after the IntWorker runs
        // and updates the state.
        var disposable = host.rendering.signal.observeValues { rendering in
            expectation.fulfill()
        }

        // Test to make sure the initial state of the workflow is correct.
        XCTAssertEqual(0, host.rendering.value.intValue)

        // Wait for the worker to run.
        wait(for: [expectation], timeout: 1.0)
        // Test to make sure the rendering after the worker runs is correct.
        XCTAssertEqual(1, host.rendering.value.intValue)

        disposable?.dispose()
        expectation = XCTestExpectation()
        // Set to observe renderings.
        // This expectation should be called after the add one action is sent.
        disposable = host.rendering.signal.observeValues { rendering in
            expectation.fulfill()
        }

        // Send an addOne action to add 1 to the state.
        host.rendering.value.addOne()

        // Wait for the action to trigger a render.
        wait(for: [expectation], timeout: 1.0)
        // Test to make sure the rendering equals 2 now that the action has run.
        XCTAssertEqual(2, host.rendering.value.intValue)

        disposable?.dispose()
        expectation = XCTestExpectation()
        // Set to observe renderings
        // Since isEquivalent is set to false in the worker
        // the worker should run again and update the rendering.
        disposable = host.rendering.signal.observeValues { rendering in
            expectation.fulfill()
        }

        // Wait for worker to run.
        wait(for: [expectation], timeout: 1)
        // Verify the rendering changed after the worker is run.
        XCTAssertEqual(1, host.rendering.value.intValue)

        disposable?.dispose()
    }

    func testEquivalentWorker() {
        // Create the workflow which causes the IntWorker to run.
        let host = WorkflowHost(
            workflow: TestIntWorkerWorkflow(key: "", isEquivalent: true)
        )

        var expectation = XCTestExpectation()
        // Set to observe renderings.
        // This expectation should be called after the IntWorker runs
        // and updates the state.
        var disposable = host.rendering.signal.observeValues { rendering in
            expectation.fulfill()
        }

        // Test to make sure the initial state of the workflow is correct.
        XCTAssertEqual(0, host.rendering.value.intValue)

        // Wait for the worker to run.
        wait(for: [expectation], timeout: 1.0)
        // Test to make sure the rendering after the worker runs is correct.
        XCTAssertEqual(1, host.rendering.value.intValue)

        disposable?.dispose()
        expectation = XCTestExpectation()
        // Set to observe renderings.
        // This expectation should be called after the add one action is sent.
        disposable = host.rendering.signal.observeValues { rendering in
            expectation.fulfill()
        }

        // Send an addOne action to add 1 to the state.
        host.rendering.value.addOne()

        // Wait for the action to trigger a render.
        wait(for: [expectation], timeout: 1.0)
        // Test to make sure the rendering equals 2 now that the action has run.
        XCTAssertEqual(2, host.rendering.value.intValue)

        disposable?.dispose()
        // Set to observe renderings
        // This expectation should be called after the workflow is updated.
        // After the host is updated with a new workflow instance the
        // initial state should be 2.
        expectation = XCTestExpectation()
        disposable = host.rendering.signal.observeValues { rendering in
            expectation.fulfill()
        }

        // Update the workflow.
        host.update(workflow: TestIntWorkerWorkflow(key: "", isEquivalent: true))
        // Wait for the workflow to render after being updated.
        wait(for: [expectation], timeout: 1.0)
        // Test to make sure the rendering matches the existing state.
        XCTAssertEqual(2, host.rendering.value.intValue)

        disposable?.dispose()
        // The workflow should not produce another rendering.
        expectation = XCTestExpectation()
        // The expectation is inverted because there should not be another rendering
        // since the worker returned isEquivalent is true.
        expectation.isInverted = true
        disposable = host.rendering.signal.observeValues { rendering in
            // This should not be called!
            expectation.fulfill()
        }

        // Wait to see if the expection is fullfulled.
        wait(for: [expectation], timeout: 1)
        // Verify the rendering didn't change and is still 2.
        XCTAssertEqual(2, host.rendering.value.intValue)

        disposable?.dispose()
    }

    func testChangingIsEquivalent() {
        // Create the workflow which causes the IntWorker to run.
        let host = WorkflowHost(
            workflow: TestIntWorkerWorkflow(key: "", isEquivalent: true)
        )

        var expectation = XCTestExpectation()
        // Set to observe renderings.
        // This expectation should be called after the IntWorker runs and
        // updates the state.
        var disposable = host.rendering.signal.observeValues { rendering in
            expectation.fulfill()
        }

        // Test to make sure the initial state of the workflow is correct.
        XCTAssertEqual(0, host.rendering.value.intValue)

        // Wait for the worker to run.
        wait(for: [expectation], timeout: 1.0)
        // Test to make sure the rendering after the worker runs is correct.
        XCTAssertEqual(1, host.rendering.value.intValue)

        disposable?.dispose()
        expectation = XCTestExpectation()
        // Set to observe renderings.
        // This expectation should be called after the add one action is sent.
        disposable = host.rendering.signal.observeValues { rendering in
            expectation.fulfill()
        }

        // Send an addOne action to add 1 to the state.
        host.rendering.value.addOne()

        // Wait for the action to trigger a render.
        wait(for: [expectation], timeout: 1.0)
        // Test to make sure the rendering equals 2 now that the action has run.
        XCTAssertEqual(2, host.rendering.value.intValue)

        disposable?.dispose()
        // Set to observe renderings.
        // This expectation should be called after the workflow is updated.
        // After the host is updated with a new workflow instance the
        // initial state should be 2.
        expectation = XCTestExpectation()
        disposable = host.rendering.signal.observeValues { rendering in
            expectation.fulfill()
        }

        // Update the workflow to change the isEquivalent for the worker.
        host.update(workflow: TestIntWorkerWorkflow(key: "", isEquivalent: false))
        // Wait for the workflow to render after being updated.
        wait(for: [expectation], timeout: 1.0)
        // Test to make sure the rendering matches the existing state.
        XCTAssertEqual(2, host.rendering.value.intValue)

        disposable?.dispose()
        expectation = XCTestExpectation()
        // Set to observe renderings
        // Since isEquivalent is set to false in the worker
        // the worker should run again and update the rendering.
        disposable = host.rendering.signal.observeValues { rendering in
            expectation.fulfill()
        }

        // Wait for worker to run.
        wait(for: [expectation], timeout: 1)
        // Verify the rendering changed after the worker is run.
        XCTAssertEqual(1, host.rendering.value.intValue)

        disposable?.dispose()
    }

    func testContinuousIntWorker() {
        let host = WorkflowHost(
            workflow: TestContinuousIntWorkerWorkflow(key: "")
        )

        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = 5
        var expectedInt = 0
        let disposable = host.rendering.signal.observeValues { rendering in
            expectedInt += 1
            XCTAssertEqual(expectedInt, rendering)
            expectation.fulfill()
        }

        XCTAssertEqual(0, host.rendering.value)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(expectedInt, host.rendering.value)

        disposable?.dispose()
    }

    func testExpectedWorker() {
        TestIntWorkerWorkflow(key: "123", isEquivalent: true)
            .renderTester()
            .expectWorkflow(
                type: AsyncSequenceWorkerWorkflow<IntWorker>.self,
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

            struct ExpectingWorker: AsyncSequenceWorker {
                typealias Output = Void

                let startExpectation: XCTestExpectation
                let endExpectation: XCTestExpectation

                func run() -> any AsyncSequence {
                    startExpectation.fulfill()
                    return AsyncStream<Output> {
                        if Task.isCancelled {
                            endExpectation.fulfill()
                            return nil
                        }
                        return ()
                    }
                    onCancel: { @Sendable () in endExpectation.fulfill() }
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

    private struct TestIntWorkerRendering {
        let intValue: Int
        let addOne: () -> Void
    }

    private struct TestIntWorkerWorkflow: Workflow {
        enum Action: WorkflowAction {
            typealias WorkflowType = TestIntWorkerWorkflow

            case add(Int)

            func apply(toState state: inout WorkflowType.State, context: ApplyContext<WorkflowType>) -> WorkflowType.Output? {
                switch self {
                case .add(let value):
                    state += value
                    return nil
                }
            }
        }

        typealias State = Int
        typealias Rendering = TestIntWorkerRendering

        let key: String
        let isEquivalent: Bool

        func makeInitialState() -> Int { 0 }

        func render(state: Int, context: RenderContext<Self>) -> TestIntWorkerRendering {
            let sink = context.makeSink(of: Action.self)

            IntWorker(isEquivalent: isEquivalent)
                .mapOutput { output in
                    AnyWorkflowAction { state in
                        state = output
                        return nil
                    }
                }
                .running(in: context, key: key)

            return TestIntWorkerRendering(intValue: state, addOne: {
                sink.send(.add(1))

            })
        }
    }

    private struct IntWorker: AsyncSequenceWorker {
        let isEquivalent: Bool

        func run() -> any AsyncSequence {
            AsyncStream<Int>(Int.self) { continuation in
                continuation.yield(1)
                continuation.finish()
            }
        }

        func isEquivalent(to otherWorker: IntWorker) -> Bool {
            isEquivalent
        }

        typealias Output = Int
    }

    private struct TestContinuousIntWorkerWorkflow: Workflow {
        typealias State = Int
        typealias Rendering = Int

        let key: String

        func makeInitialState() -> Int { 0 }

        func render(state: Int, context: RenderContext<Self>) -> Int {
            ContinuousIntWorker()
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

    private struct ContinuousIntWorker: AsyncSequenceWorker {
        func run() -> any AsyncSequence {
            var i = 0
            return AsyncStream<Int> {
                i += 1
                return i
            }
        }

        func isEquivalent(to otherWorker: ContinuousIntWorker) -> Bool {
            true
        }

        typealias Output = Int
    }
}

import XCTest
@testable import Workflow

@MainActor
final class AsyncSideEffectTests: XCTestCase {
    func test_asyncSideEffect_starts_and_isCancelledWhenKeyDisappears() async {
        let started = expectation(description: "side effect started")
        let cancelled = expectation(description: "side effect cancelled")

        let host = WorkflowHost(
            workflow: ToggleWorkflow(
                runEffect: true,
                onStart: { started.fulfill() },
                onCancel: { cancelled.fulfill() }
            )
        )

        await fulfillment(of: [started], timeout: 1)

        // Re-render without the side effect: the key disappears, the Task
        // must receive cooperative cancellation.
        host.update(workflow: ToggleWorkflow(runEffect: false, onStart: {}, onCancel: {}))

        await fulfillment(of: [cancelled], timeout: 1)
    }

    func test_asyncSideEffect_runsOnlyOncePerKey_acrossRenders() async {
        let counter = StartCounter()
        let ran = expectation(description: "side effect ran")
        // Over-fulfillment (a second Task starting) fails the test.
        ran.assertForOverFulfill = true

        let host = WorkflowHost(
            workflow: CountingWorkflow(counter: counter, onRun: { ran.fulfill() })
        )
        host.update(workflow: CountingWorkflow(counter: counter, onRun: { ran.fulfill() }))
        host.update(workflow: CountingWorkflow(counter: counter, onRun: { ran.fulfill() }))

        await fulfillment(of: [ran], timeout: 1)
        XCTAssertEqual(counter.count, 1)
    }

    // MARK: - Fixtures

    fileprivate final class StartCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var _count = 0
        var count: Int { lock.withLock { _count } }
        func increment() { lock.withLock { _count += 1 } }
    }

    fileprivate struct ToggleWorkflow: Workflow {
        var runEffect: Bool
        var onStart: @Sendable () -> Void
        var onCancel: @Sendable () -> Void

        typealias State = Void
        typealias Rendering = Void

        func render(state: State, context: RenderContext<ToggleWorkflow>) {
            if runEffect {
                let onStart = onStart
                let onCancel = onCancel
                context.runSideEffect(key: "effect") {
                    onStart()
                    do {
                        try await Task.sleep(nanoseconds: 10000000000)
                    } catch is CancellationError {
                        onCancel()
                    } catch {}
                }
            }
        }
    }

    fileprivate struct CountingWorkflow: Workflow {
        var counter: StartCounter
        var onRun: @Sendable () -> Void

        typealias State = Void
        typealias Rendering = Void

        func render(state: State, context: RenderContext<CountingWorkflow>) {
            let counter = counter
            let onRun = onRun
            context.runSideEffect(key: "count") {
                counter.increment()
                onRun()
            }
        }
    }
}

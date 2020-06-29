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

import ReactiveSwift
import Workflow
import WorkflowReactiveSwift
import WorkflowReactiveSwiftTesting
import WorkflowTesting
import XCTest

class WorkerTests: XCTestCase {
    func testExpectedWorker() {
        SignalProducerTestWorkflow()
            .renderTester()
            .expect(worker: SignalProducerTestWorker(), producingOutput: 1)
            .render { _ in }
            .verifyState { state in
                XCTAssertEqual(state, 1)
            }
    }

    func testWorkerOutput() {
        let host = WorkflowHost(
            workflow: SignalProducerTestWorkflow()
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

    func testExpectedWorkerDeprecatedTests() {
        SignalProducerTestWorkflow()
            .renderTester()
            .render(
                expectedState: ExpectedState(state: 1),
                expectedWorkers: [ExpectedWorker(worker: SignalProducerTestWorker(), output: 1)]
            )
    }
}

private struct SignalProducerTestWorkflow: Workflow {
    typealias State = Int
    typealias Rendering = Int

    func makeInitialState() -> Int {
        0
    }

    func render(state: Int, context: RenderContext<SignalProducerTestWorkflow>) -> Int {
        SignalProducerTestWorker()
            .mapOutput { output in
                AnyWorkflowAction { state in
                    state = output
                    return nil
                }
            }
            .running(in: context)
        return state
    }
}

private struct SignalProducerTestWorker: Worker {
    typealias Output = Int
    func run() -> SignalProducer<Int, Never> {
        return SignalProducer { observer, lifetime in
            observer.send(value: 1)
        }
    }

    func isEquivalent(to otherWorker: SignalProducerTestWorker) -> Bool {
        true
    }
}

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

import Foundation
import RxSwift
import WorkflowRxSwift
import WorkflowRxSwiftTesting
import WorkflowTesting
import XCTest
@testable import Workflow

class WorkerTests: XCTestCase {
    func testExpectedWorker() {
        ObservableTestWorkflow(key: "123")
            .renderTester()
            .expect(worker: ObservableTestWorker(), producingOutput: 1, key: "123")
            .render { _ in }
            .verifyState { state in
                XCTAssertEqual(state, 1)
            }
    }

    func testWorkerOutput() {
        let host = WorkflowHost(
            workflow: ObservableTestWorkflow(key: "")
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

    // A worker declared on a first `render` pass that is not on a subsequent should have the work cancelled.
    func test_cancelsWorkers() {
        struct WorkerWorkflow: Workflow {
            var startExpectation: XCTestExpectation
            var endExpectation: XCTestExpectation

            enum State {
                case notWorking
                case working
            }

            func makeInitialState() -> WorkerWorkflow.State {
                return .notWorking
            }

            func render(state: WorkerWorkflow.State, context: RenderContext<WorkerWorkflow>) -> Bool {
                switch state {
                case .notWorking:
                    return false
                case .working:
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
                var startExpectation: XCTestExpectation
                var endExpectation: XCTestExpectation

                typealias Output = Void

                func run() -> Observable<Void> {
                    Observable<Void>
                        .just(())
                        .do(onSubscribed: {
                            self.startExpectation.fulfill()
                        }, onDispose: {
                            self.endExpectation.fulfill()
                    })
                }

                func isEquivalent(to otherWorker: WorkerWorkflow.ExpectingWorker) -> Bool {
                    return true
                }
            }
        }

        let startExpectation = XCTestExpectation()
        let endExpectation = XCTestExpectation()
        let manager = WorkflowNode<WorkerWorkflow>.SubtreeManager()

        let isRunning = manager.render { context -> Bool in
            WorkerWorkflow(
                startExpectation: startExpectation,
                endExpectation: endExpectation
            )
            .render(
                state: .working,
                context: context
            )
        }

        XCTAssertEqual(true, isRunning)
        wait(for: [startExpectation], timeout: 1.0)

        let isStillRunning = manager.render { context -> Bool in
            WorkerWorkflow(
                startExpectation: startExpectation,
                endExpectation: endExpectation
            )
            .render(
                state: .notWorking,
                context: context
            )
        }

        XCTAssertFalse(isStillRunning)
        wait(for: [endExpectation], timeout: 1.0)
    }

    func test_handlesRepeatedWorkerOutputs() {
        struct WF: Workflow {
            typealias Output = Int
            typealias Rendering = Void

            func render(state: Void, context: RenderContext<WF>) {
                TestWorker()
                    .mapOutput { AnyWorkflowAction(sendingOutput: $0) }
                    .running(in: context)
            }
        }

        struct TestWorker: Worker {
            func isEquivalent(to otherWorker: TestWorker) -> Bool {
                return true
            }

            func run() -> Observable<Int> {
                return Observable.from([1, 2]).delay(.milliseconds(1), scheduler: MainScheduler.asyncInstance)
            }
        }

        let expectation = XCTestExpectation(description: "Test Worker")
        var outputs: [Int] = []

        let node = WorkflowNode(workflow: WF())
        node.onOutput = { output in
            if let outputInt = output.outputEvent {
                outputs.append(outputInt)

                if outputs.count == 2 {
                    expectation.fulfill()
                }
            }
        }

        node.render()
        node.enableEvents()

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(outputs, [1, 2])
    }
}

private struct ObservableTestWorkflow: Workflow {
    typealias State = Int
    typealias Rendering = Int

    let key: String

    func makeInitialState() -> Int {
        0
    }

    func render(state: Int, context: RenderContext<Self>) -> Int {
        ObservableTestWorker()
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

private struct ObservableTestWorker: Worker {
    func run() -> Observable<Int> {
        Observable.just(1)
    }

    func isEquivalent(to otherWorker: Self) -> Bool {
        true
    }
}

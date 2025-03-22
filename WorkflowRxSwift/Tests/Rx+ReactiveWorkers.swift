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
import ReactiveSwift
import RxSwift
import Workflow
import WorkflowReactiveSwift
import XCTest

class Rx_ReactiveWorkersTests: XCTestCase {
    func test_outputs_fromRxSwiftAndReactiveSwift() {
        let host = WorkflowHost(
            workflow: CombinedWorkflow()
        )

        let expectation = XCTestExpectation()
        let disposable = host.output.signal.observeValues { output in
            if output.reactiveOutputReceived, output.rxOutputReceived {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1.0)

        disposable?.dispose()
    }

    func test_observes_on_main_queue() {
        struct TestWorkflow: Workflow {
            enum Action: WorkflowAction {
                typealias WorkflowType = TestWorkflow
                case complete

                func apply(toState state: inout State, workflow: WorkflowType) -> Output? {
                    switch self {
                    case .complete:
                        .finished
                    }
                }
            }

            enum Output {
                case finished
            }

            func render(state: Void, context: RenderContext<Self>) {
                Single<Void>.create { observer in
                    DispatchQueue.global().async {
                        observer(.success(()))
                    }
                    return Disposables.create()
                }
                .asObservable()
                .running(in: context) { _ in
                    XCTAssert(Thread.isMainThread)
                    return Action.complete
                }
            }
        }

        let host = WorkflowHost(
            workflow: TestWorkflow()
        )

        let expectation = XCTestExpectation()
        let disposable = host.output.signal.observeValues { output in
            if output == .finished {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1.0)
        disposable?.dispose()
    }
}

struct CombinedWorkflow: Workflow {
    typealias Rendering = Void
    typealias Output = State

    struct State {
        var rxOutputReceived: Bool
        var reactiveOutputReceived: Bool
    }

    enum Action: WorkflowAction {
        typealias WorkflowType = CombinedWorkflow

        case rxSwift
        case reactiveSwift

        func apply(toState state: inout CombinedWorkflow.State, workflow: WorkflowType) -> CombinedWorkflow.State? {
            switch self {
            case .rxSwift:
                state.rxOutputReceived = true
            case .reactiveSwift:
                state.reactiveOutputReceived = true
            }
            return state
        }
    }

    func makeInitialState() -> State {
        .init(rxOutputReceived: false, reactiveOutputReceived: false)
    }

    func render(state: State, context: RenderContext<CombinedWorkflow>) {
        SignalProducer(value: true)
            .mapOutput { _ in Action.reactiveSwift }
            .running(in: context)

        Observable.just(true)
            .mapOutput { _ in Action.rxSwift }
            .running(in: context)
    }
}

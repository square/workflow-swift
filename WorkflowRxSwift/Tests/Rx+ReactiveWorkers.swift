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
        _ = host.addOutputListener { output in
            if output.reactiveOutputReceived, output.rxOutputReceived {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1.0)
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

        func apply(toState state: inout CombinedWorkflow.State) -> CombinedWorkflow.State? {
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

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
import XCTest
@testable import Workflow

class SignalTests: XCTestCase {
    func test_output() {
        let (signal, observer) = Signal<Int, Never>.pipe()
        let host = WorkflowHost(
            workflow: SignalTestWorkflow(signal: signal)
        )

        let expectation = XCTestExpectation()
        var outputValue: Int?
        let disposable = host.outputSignal.observeValues { output in
            outputValue = output
            expectation.fulfill()
        }
        defer {
            disposable?.dispose()
        }

        observer.send(value: 1)

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(1, outputValue)
    }

    func test_multipleOutputs() {
        let (signal, observer) = Signal<Int, Never>.pipe()
        let host = WorkflowHost(
            workflow: SignalTestWorkflow(signal: signal)
        )

        let expectation = XCTestExpectation()
        var outputValues = [Int]()
        let disposable = host.outputSignal.observeValues { output in
            outputValues.append(output)
            if outputValues.count == 3 {
                expectation.fulfill()
            }
        }
        defer {
            disposable?.dispose()
        }

        observer.send(value: 1)
        observer.send(value: 2)
        observer.send(value: 3)

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual([1, 2, 3], outputValues)
    }

    func test_signal_disposal() {
        let (signal, _) = Signal<Int, Never>.pipe()

        let expectation = XCTestExpectation()
        let signalOne = signal.on(disposed: {
            expectation.fulfill()
        })

        let (signalTwo, _) = Signal<Int, Never>.pipe()

        let host = WorkflowHost(
            workflow: SignalTestWorkflow(signal: signalOne)
        )

        host.update(workflow: SignalTestWorkflow(signal: signalTwo))
        wait(for: [expectation], timeout: 1)
    }
}

private struct SignalTestWorkflow<Value>: Workflow {
    typealias Rendering = Void
    typealias Output = Value
    typealias State = Void

    let signal: Signal<Value, Never>

    func render(state: State, context: RenderContext<SignalTestWorkflow<Value>>) {
        signal.mapOutput {
            AnyWorkflowAction(sendingOutput: $0)
        }.running(in: context)
    }
}

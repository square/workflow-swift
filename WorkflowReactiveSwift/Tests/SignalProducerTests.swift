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
import WorkflowTesting
import XCTest
@testable import Workflow
@testable import WorkflowReactiveSwift

class SignalProducerTests: XCTestCase {
    func test_signalProducerWorkflow_usesSideEffectWithKey() {
        let signalProducer = SignalProducer(value: 1)
        SignalProducerWorkflow(signalProducer: signalProducer)
            .renderTester()
            .expectSideEffect(key: "")
            .render { _ in }
    }

    func test_output() {
        let signalProducer = SignalProducer(value: 1)

        let host = WorkflowHost(
            workflow: SignalProducerWorkflow(signalProducer: signalProducer)
        )

        let expectation = XCTestExpectation()
        var outputValue: Int?
        let disposable = host.output.signal.observeValues { output in
            outputValue = output
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(1, outputValue)

        disposable?.dispose()
    }

    func test_multipleOutputs() {
        let signalProducer = SignalProducer(values: 1, 2, 3)

        let host = WorkflowHost(
            workflow: SignalProducerWorkflow(signalProducer: signalProducer)
        )

        let expectation = XCTestExpectation()
        var outputValues = [Int]()
        let disposable = host.output.signal.observeValues { output in
            outputValues.append(output)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual([1, 2, 3], outputValues)

        disposable?.dispose()
    }

    func test_signalProducer_isDisposedIfNotUsedInWorkflow() {
        let expectation = XCTestExpectation(description: "SignalProducer should be disposed if no longer used.")
        let signalProducer = SignalProducer(values: 1, 2, 3)
            .on(disposed: {
                expectation.fulfill()
            })

        let host = WorkflowHost(
            workflow: SignalProducerWorkflow(signalProducer: signalProducer)
        )

        let signalProducerTwo = SignalProducer(values: 1, 2, 3)
        host.update(workflow: SignalProducerWorkflow(signalProducer: signalProducerTwo))

        wait(for: [expectation], timeout: 1)
    }
}

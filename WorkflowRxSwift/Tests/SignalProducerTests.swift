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

import RxSwift
import WorkflowRxSwiftTesting
import WorkflowTesting
import XCTest
@testable import Workflow
@testable import WorkflowRxSwift

class SignalProducerTests: XCTestCase {
    func test_signalProducerWorkflow_usesSideEffectWithKey() {
        let observable = Observable.just(1)
        ObservableWorkflow(observable: observable)
            .renderTester()
            .expectSideEffect(key: "")
            .render { _ in }
    }

    func test_output() {
        let observable = Observable.just(1)

        let host = WorkflowHost(
            workflow: ObservableWorkflow(observable: observable)
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
        let observable = Observable.from([1, 2, 3])

        let host = WorkflowHost(
            workflow: ObservableWorkflow(observable: observable)
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
        let observable = Observable.from([1, 2, 3])
            .do(onDispose: {
                expectation.fulfill()
        })

        let host = WorkflowHost(
            workflow: ObservableWorkflow(observable: observable)
        )

        let observableTwo = Observable.from([1, 2, 3])
        host.update(workflow: ObservableWorkflow(observable: observableTwo))

        wait(for: [expectation], timeout: 1)
    }
}

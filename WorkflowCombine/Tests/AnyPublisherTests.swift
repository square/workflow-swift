/*
 * Copyright 2021 Square Inc.
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

import Combine
import Foundation
import Workflow
import XCTest
@testable import WorkflowCombine

class AnyPublisherTests: XCTestCase {
    func testPublisherWorkflow() {
        TestWorkflow()
            .renderTester()
            .expectPublisher(producingOutput: 1, key: "123")
            .render {}
    }

    struct TestWorkflow: Workflow {
        typealias State = Void
        typealias Rendering = Void

        func render(state: State, context: RenderContext<Self>) -> Rendering {
            Just(1)
                .map { _ in AnyWorkflowAction<TestWorkflow>.noAction }
                .eraseToAnyPublisher()
                .running(in: context, key: "123")
        }
    }

    func test_publisherWorkflow_usesSideEffectWithKey() {
        let publisher = Just(1).eraseToAnyPublisher()
        PublisherWorkflow(publisher: publisher)
            .renderTester()
            .expectSideEffect(key: "")
            .render { _ in }
    }

    func test_output() {
        let publisher = Just(1).eraseToAnyPublisher()

        let host = WorkflowHost(
            workflow: PublisherWorkflow(publisher: publisher)
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
        let publisher = [1, 2, 3].publisher

        let host = WorkflowHost(
            workflow: PublisherWorkflow(publisher: publisher.eraseToAnyPublisher())
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

    func test_publisher_isDisposedIfNotUsedInWorkflow() {
        let expectation = XCTestExpectation(description: "SignalProducer should be disposed if no longer used.")
        let publisher = [1, 2, 3]
            .publisher
            .handleEvents(receiveCompletion: { _ in
                expectation.fulfill()
            })
            .eraseToAnyPublisher()

        let host = WorkflowHost(
            workflow: PublisherWorkflow(publisher: publisher)
        )

        let publisherTwo = [1, 2, 3].publisher.eraseToAnyPublisher()
        host.update(workflow: PublisherWorkflow(publisher: publisherTwo))

        wait(for: [expectation], timeout: 1)
    }
}

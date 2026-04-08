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
import WorkflowCombineTesting
import XCTest
@testable import WorkflowCombine

class PublisherTests: XCTestCase {
    func test_publisherWorkflow_usesSideEffectWithKey() {
        PublisherWorkflow(publisher: Just(1))
            .renderTester()
            .expectSideEffect(key: "")
            .render { _ in }
    }

    func test_output() {
        let host = WorkflowHost(
            workflow: PublisherWorkflow(publisher: Just(1))
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
            workflow: PublisherWorkflow(publisher: publisher)
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

    func test_switchingConcretePublisherType_cancelsAndResubscribes() {
        let firstSubscribed = expectation(description: "first publisher subscribed")
        let firstCancelled = expectation(description: "first publisher cancelled")
        let secondSubscribed = expectation(description: "second publisher subscribed")

        let first = PassthroughSubject<Int, Never>()
        let second = PassthroughSubject<Int, Never>()
        let host = WorkflowHost(
            workflow: SwitchingPublisherTypeWorkflow(
                mode: .first,
                first: first,
                second: second,
                firstSubscribed: firstSubscribed,
                firstCancelled: firstCancelled,
                secondSubscribed: secondSubscribed
            )
        )

        wait(for: [firstSubscribed], timeout: 1)

        host.update(
            workflow: SwitchingPublisherTypeWorkflow(
                mode: .second,
                first: first,
                second: second,
                firstSubscribed: firstSubscribed,
                firstCancelled: firstCancelled,
                secondSubscribed: secondSubscribed
            )
        )

        wait(for: [firstCancelled, secondSubscribed], timeout: 1)
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

private struct SwitchingPublisherTypeWorkflow: Workflow {
    typealias State = Void
    typealias Rendering = Void
    typealias Output = Int

    enum Mode {
        case first
        case second
    }

    let mode: Mode
    let first: PassthroughSubject<Int, Never>
    let second: PassthroughSubject<Int, Never>
    let firstSubscribed: XCTestExpectation
    let firstCancelled: XCTestExpectation
    let secondSubscribed: XCTestExpectation

    func render(state: State, context: RenderContext<Self>) {
        switch mode {
        case .first:
            first
                .handleEvents(
                    receiveSubscription: { _ in
                        firstSubscribed.fulfill()
                    },
                    receiveCancel: {
                        firstCancelled.fulfill()
                    }
                )
                .mapOutput { AnyWorkflowAction<Self>(sendingOutput: $0) }
                .running(in: context, key: "publisher")
        case .second:
            second
                .map { $0 }
                .handleEvents(receiveSubscription: { _ in
                    secondSubscribed.fulfill()
                })
                .mapOutput { AnyWorkflowAction<Self>(sendingOutput: $0) }
                .running(in: context, key: "publisher")
        }
    }
}

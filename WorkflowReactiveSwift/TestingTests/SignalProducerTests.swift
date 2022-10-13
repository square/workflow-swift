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
import Workflow
import WorkflowReactiveSwiftTesting
import XCTest

class SignalProducerTests: XCTestCase {
    func test_signalProducerWorkflow() {
        TestWorkflow()
            .renderTester()
            .expectSignalProducer(producingOutput: 1, key: "123")
            .render {}
    }

    func test_multipleChildSignalProducerWorkflows() {
        TestWorkflow(childKeys: ["123", "456"])
            .renderTester()
            .expectSignalProducer(
                // value is arbitrary, but needed to specify the output type
                producingOutput: 42,
                key: "123"
            )
            .expectSignalProducer(
                producingOutput: nil as Int?,
                key: "456"
            )
            .render {}
    }

    func test_signalProducerWorkflow_noOutput() {
        TestWorkflow()
            .renderTester()
            .expectSignalProducer(outputType: Int.self, key: "123")
            .render {}
    }

    private struct TestWorkflow: Workflow {
        typealias State = Void
        typealias Rendering = Void

        var childKeys: [String] = ["123"]

        func render(state: State, context: RenderContext<Self>) -> Rendering {
            for key in childKeys {
                SignalProducer(value: 1)
                    .mapOutput { _ in AnyWorkflowAction<TestWorkflow>.noAction }
                    .running(in: context, key: key)
            }
        }
    }
}

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
}

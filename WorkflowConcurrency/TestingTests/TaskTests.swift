/*
 * Copyright 2022 Square Inc.
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
import Workflow
import WorkflowTesting
import XCTest
@testable import WorkflowConcurrencyTesting

@available(iOS 13.0, macOS 10.15, *)
class TaskTests: XCTestCase {
    func testTaskWorkflow() {
        TestWorkflow()
            .renderTester()
            .expect(task: Task<Int, Never>.self, output: 1, key: "123")
            .render {}
    }

    struct TestWorkflow: Workflow {
        typealias State = Void
        typealias Rendering = Void

        func render(state: State, context: RenderContext<Self>) -> Rendering {
            Task {
                1
            }
            .mapOutput { _ in AnyWorkflowAction<TestWorkflow>.noAction }
            .running(in: context, key: "123")
        }
    }
}

/*
 * Copyright Square Inc.
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

import Testing
import Workflow
import XCTest

@testable import WorkflowTesting

struct SwiftTestingCompatibilityTests {
    @Test
    func testInternalFailureRecordsExpectationFailure_swiftTesting() {
        withKnownIssue {
            TestAction
                .tester(withState: false)
                .send(action: .change(true))
                .assertNoOutput() // should fail the test
        }
    }
}

final class XCTestCompatibilityTests: XCTestCase {
    func testInternalFailureRecordsExpectationFailure_xctest() {
        XCTExpectFailure {
            _ = TestAction
                .tester(withState: false)
                .send(action: .change(true))
                .assertNoOutput() // should fail the test
        }
    }
}

private enum TestAction: WorkflowAction {
    typealias WorkflowType = TestWorkflow

    case change(Bool)

    func apply(toState state: inout Bool) -> TestWorkflow.Output? {
        if case .change(let newState) = self {
            state = newState
        }
        return 42
    }
}

private struct TestWorkflow: Workflow {
    typealias Rendering = Void
    typealias Output = Int

    func makeInitialState() -> Bool { true }
    func render(state: Bool, context: RenderContext<TestWorkflow>) {}
}

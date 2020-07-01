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
import Workflow
import XCTest
@testable import WorkflowTesting

final class WorkflowActionTesterTests: XCTestCase {
    func test_stateTransitions() {
        TestAction
            .tester(withState: false)
            .send(action: .toggleTapped)
            .verifyState { XCTAssertTrue($0) }
    }

    func test_stateTransitions_equatable() {
        TestAction
            .tester(withState: false)
            .send(action: .toggleTapped)
            .assert(state: true)
    }

    func test_noOutputs() {
        TestAction
            .tester(withState: false)
            .send(action: .toggleTapped)
            .assertNoOutput()
    }

    func test_outputs() {
        TestAction
            .tester(withState: false)
            .send(action: .exitTapped)
            .verifyOutput { output in
                XCTAssertEqual(output, .finished)
            }
    }

    func test_outputs_equatable() {
        TestAction
            .tester(withState: false)
            .send(action: .exitTapped)
            .assert(output: .finished)
    }

    func test_deprecated_methods() {
        TestAction
            .tester(withState: false)
            .send(action: .exitTapped)
            .assert(output: .finished)
            .verifyState { state in
                XCTAssertFalse(state)
            }
    }

    func test_testerExtension() {
        let state = true
        let tester = TestAction
            .tester(withState: true)
        XCTAssertEqual(state, tester.state)
        XCTAssertNil(tester.output)
    }
}

private enum TestAction: WorkflowAction {
    case toggleTapped
    case exitTapped

    typealias WorkflowType = TestWorkflow

    func apply(toState state: inout Bool) -> TestWorkflow.Output? {
        switch self {
        case .toggleTapped:
            state = !state
            return nil
        case .exitTapped:
            return .finished
        }
    }
}

private struct TestWorkflow: Workflow {
    typealias State = Bool

    enum Output {
        case finished
    }

    func makeInitialState() -> Bool {
        return true
    }

    func render(state: Bool, context: RenderContext<TestWorkflow>) {
        return ()
    }
}

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

import IssueReporting
import Testing
import Workflow
@testable import WorkflowTesting

struct WorkflowActionTesterTests {
    @Test func stateTransitions() {
        TestAction
            .tester(withState: false)
            .send(action: .toggleTapped)
            .verifyState { #expect($0) }
    }

    @Test func stateTransitions_throw() throws {
        try TestAction
            .tester(withState: false)
            .send(action: .toggleTapped)
            .verifyState {
                try throwingNoop()
                #expect($0)
            }
    }

    @Test func stateTransitions_equatable() {
        TestAction
            .tester(withState: false)
            .send(action: .toggleTapped)
            .assert(state: true)
    }

    @Test func noOutputs() {
        TestAction
            .tester(withState: false)
            .send(action: .toggleTapped)
            .assertNoOutput()
    }

    @Test func outputs() {
        TestAction
            .tester(withState: false)
            .send(action: .exitTapped)
            .verifyOutput { output in
                #expect(output == .finished)
            }
    }

    @Test func outputs_throw() throws {
        try TestAction
            .tester(withState: false)
            .send(action: .exitTapped)
            .verifyOutput { output in
                try throwingNoop()
                #expect(output == .finished)
            }
    }

    @Test func outputs_equatable() {
        TestAction
            .tester(withState: false)
            .send(action: .exitTapped)
            .assert(output: .finished)
    }

    @Test func deprecated_methods() {
        TestAction
            .tester(withState: false)
            .send(action: .exitTapped)
            .assert(output: .finished)
            .verifyState { state in
                #expect(!state)
            }
    }

    @Test func erExtension() {
        let state = true
        let tester = TestAction
            .tester(withState: true)
        #expect(state == tester.state)
        #expect(tester.output == nil)
    }
}

// MARK: - ApplyContext Tests

extension WorkflowActionTesterTests {
    @Test func old_api_still_work_if_props_arent_read() {
        TestActionWithProps
            .tester(withState: true)
            .send(action: .dontReadProps)
            .assert(state: true)
            .assert(output: .value("did not read props"))
    }

    @Test func new_api_works_if_you_provide_props() {
        TestActionWithProps
            .tester(
                withState: true,
                workflow: TestWorkflow(prop: 42)
            )
            .send(action: .readProp)
            .assert(state: true)
            .assert(output: .value("read prop: 42"))
    }

    @Test func new_api_works_with_optional_props() {
        TestActionWithProps
            .tester(
                withState: true,
                workflow: TestWorkflow(prop: 42, optionalProp: 22)
            )
            .send(action: .readOptionalProp)
            .assert(state: true)
            .assert(output: .value("read optional prop: 22"))

        TestActionWithProps
            .tester(
                withState: true,
                workflow: TestWorkflow(prop: 42, optionalProp: nil)
            )
            .send(action: .readOptionalProp)
            .assert(state: true)
            .assert(output: .value("read optional prop: <nil>"))
    }
}

// withExpectedIssue records a known issue under Swift Testing, which
// causes xcodebuild to exit with code 65. Keep this as XCTest until
// that xcodebuild bug is resolved.
import XCTest

final class WorkflowActionTesterExpectedFailureTests: XCTestCase {
    func test_old_api_errors_accessing_optional_through_apply_context_without_proper_setup() {
        withExpectedIssue("reading optional value through context without workflow should fail but not crash") {
            TestActionWithProps
                .tester(withState: true)
                .send(action: .readOptionalProp)
                .assert(state: true)
        }
    }
}

// MARK: -

private enum TestActionWithProps: WorkflowAction {
    typealias WorkflowType = TestWorkflow

    case readProp
    case readOptionalProp
    case dontReadProps

    func apply(
        toState state: inout Bool,
        context: ApplyContext<TestWorkflow>
    ) -> TestWorkflow.Output? {
        switch self {
        case .dontReadProps:
            return .value("did not read props")

        case .readProp:
            let prop = context[workflowValue: \.prop]
            return .value("read prop: \(prop)")

        case .readOptionalProp:
            let optionalProp = context[workflowValue: \.optionalProp]
            return .value("read optional prop: \(optionalProp?.description ?? "<nil>")")
        }
    }
}

private enum TestAction: WorkflowAction {
    case toggleTapped
    case exitTapped

    typealias WorkflowType = TestWorkflow

    func apply(toState state: inout Bool, context: ApplyContext<WorkflowType>) -> TestWorkflow.Output? {
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

    enum Output: Equatable {
        case finished
        case value(String)
    }

    var prop = 0
    var optionalProp: Int? = 42

    func makeInitialState() -> Bool {
        true
    }

    func render(state: Bool, context: RenderContext<TestWorkflow>) {
        ()
    }
}

private func throwingNoop() throws {}

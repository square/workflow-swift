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

import Workflow
import WorkflowTesting
import XCTest

/// Who tests the tester?
///
/// WorkflowRenderTesterFailureTests does.
///
/// Tests that the assertion failures actually assert failures.
final class WorkflowRenderTesterFailureTests: XCTestCase {
    var expectedFailureStrings: [String] = []

    @discardableResult
    func expectingFailure<Result>(
        _ messageSubstring: String,
        file: StaticString = #file, line: UInt = #line,
        perform: () -> Result
    ) -> Result {
        expectingFailures([messageSubstring], file: file, line: line, perform: perform)
    }

    @discardableResult
    func expectingFailures<Result>(
        _ messageSubstrings: [String],
        file: StaticString = #file, line: UInt = #line,
        perform: () -> Result
    ) -> Result {
        expectedFailureStrings = messageSubstrings
        let result = perform()
        if !expectedFailureStrings.isEmpty {
            let leftOverExpectedFailures = expectedFailureStrings
            expectedFailureStrings = []
            for failure in leftOverExpectedFailures {
                XCTFail(#"Expected failure matching "\#(failure)""#, file: file, line: line)
            }
        }
        return result
    }

    /// Check for the given failure description and remove it if there’s a matching expected failure
    /// - Parameter description: The failure description to check & remove
    /// - Returns: `true` if the failure was expected and removed, otherwise `false`
    private func removeFailure(withDescription description: String) -> Bool {
        if let matchedIndex = expectedFailureStrings.firstIndex(where: { description.contains($0) }) {
            expectedFailureStrings.remove(at: matchedIndex)
            return true
        } else {
            return false
        }
    }

    // Undeprecated API on Xcode 12+ (which ships with Swift 5.3)
    override func record(_ issue: XCTIssue) {
        if removeFailure(withDescription: issue.compactDescription) {
            // Don’t forward the issue, it was expected
        } else {
            super.record(issue)
        }
    }

    // MARK: Child workflows

    func test_childWorkflow_missing() {
        let tester = TestWorkflow()
            .renderTester(initialState: .idle)
            .expectWorkflow(
                type: TestChildWorkflow.self,
                producingRendering: "nope",
                assertions: { _ in
                    XCTFail("Should never be called")
                }
            )

        expectingFailure(#"Expected child workflow of type: TestChildWorkflow, key: """#) {
            tester.render { _ in }
        }
    }

    func test_childWorkflow_assertion() {
        let tester = TestWorkflow()
            .renderTester(initialState: .workflow(param: "", key: ""))
            .expectWorkflow(type: TestChildWorkflow.self, key: "", producingRendering: "", producingOutput: nil) { workflow in
                XCTFail("Workflow Assertion Fired")
            }

        expectingFailure("Workflow Assertion Fired") {
            tester.render { _ in }
        }
    }

    func test_childWorkflow_unexpected_voidRendering() {
        // We can’t test non-void-rendering workflow failures because we must
        // return a rendering from the render context, but we _can_ test
        // unexpected workflows that render Void.

        let tester = TestWorkflow()
            .renderTester(initialState: .voidWorkflow)

        expectingFailure(#"unexpected Workflow of type VoidWorkflow with key "". If this child Workflow is expected, please add a call to `expectWorkflow(...)` with the appropriate parameters before invoking `render()`."#) {
            tester.render { _ in }
        }
    }

    func test_childWorkflowMultipleRenders_sameKey() {
        let tester = ParentWorkflow()
            .renderTester()
            .expectWorkflow(type: ChildWorkflow.self, producingRendering: 0)
            .expectWorkflow(type: ChildWorkflow.self, producingRendering: 0)

        expectingFailure(#"Multiple Workflows of type ChildWorkflow with key "" used in the same render call. Use a unique key to render multiple Workflows of the same type."#) {
            tester.render { _ in }
        }

        struct ParentWorkflow: Workflow {
            typealias State = Void
            typealias Rendering = Void

            func render(state: Void, context: RenderContext<ParentWorkflow>) {
                _ = ChildWorkflow().rendered(in: context) { _ in
                    AnyWorkflowAction<ParentWorkflow>.noAction
                }
                _ = ChildWorkflow().rendered(in: context) { _ in
                    AnyWorkflowAction<ParentWorkflow>.noAction
                }
            }
        }

        struct ChildWorkflow: Workflow {
            typealias State = Void
            typealias Rendering = Int
            typealias Output = Void

            func render(state: Void, context: RenderContext<ChildWorkflow>) -> Int {
                0
            }
        }
    }

    func test_childWorkflowMultipleRenders_differentKeys() {
        ParentWorkflow()
            .renderTester()
            .expectWorkflow(type: ChildWorkflow.self, key: "0", producingRendering: 0)
            .expectWorkflow(type: ChildWorkflow.self, key: "1", producingRendering: 0)
            .render { _ in }

        struct ParentWorkflow: Workflow {
            typealias State = Void
            typealias Rendering = Void

            func render(state: Void, context: RenderContext<ParentWorkflow>) {
                _ = ChildWorkflow().rendered(in: context, key: "0") { _ in
                    AnyWorkflowAction<ParentWorkflow>.noAction
                }
                _ = ChildWorkflow().rendered(in: context, key: "1") { _ in
                    AnyWorkflowAction<ParentWorkflow>.noAction
                }
            }
        }

        struct ChildWorkflow: Workflow {
            typealias State = Void
            typealias Rendering = Int
            typealias Output = Void

            func render(state: Void, context: RenderContext<ChildWorkflow>) -> Int {
                0
            }
        }
    }

    // MARK: Side effects

    func test_sideEffect_missing() {
        let tester = TestWorkflow()
            .renderTester(initialState: .idle)
            .expectSideEffect(key: "side-effect")

        expectingFailure(#"Expected side-effect with key: "side-effect""#) {
            tester.render { _ in }
        }
    }

    func test_sideEffect_mismatch() {
        let tester = TestWorkflow()
            .renderTester(initialState: .sideEffect(key: "actual"))
            .expectSideEffect(key: "expected")

        expectingFailures([
            #"Unexpected side-effect with key "actual""#,
            #"Expected side-effect with key: "expected""#,
        ]) {
            tester.render { _ in }
        }
    }

    func test_sideEffect_unexpected() {
        let tester = TestWorkflow()
            .renderTester(initialState: .sideEffect(key: "input"))

        expectingFailure(#"Unexpected side-effect with key "input""#) {
            tester.render { _ in }
        }
    }

    // MARK: Actions

    func test_verifyAction() {
        let result = TestWorkflow()
            .renderTester(initialState: .idle)
            .render { rendering in
                rendering.doNoopAction(10)
            }

        expectingFailure(#"("noop(10)") is not equal to ("noop(70)")"#) {
            result.assert(action: TestAction.noop(70))
        }

        expectingFailure("My own little action error") {
            result.verifyAction { (action: TestAction) in
                XCTAssertEqual(action, TestAction.sendOutput("nah"), "My own little action error")
            }
        }

        expectingFailure("Expected no action, but got noop(10)") {
            result.assertNoAction()
        }
    }

    func test_verifyAction_no_action() {
        let result = TestWorkflow()
            .renderTester(initialState: .idle)
            .render { _ in }

        expectingFailure("No action was produced") {
            result.assert(action: TestAction.noop(1))
        }

        expectingFailure("No action was produced") {
            result.verifyAction { (action: TestAction) in
                XCTFail("Should not get called")
            }
        }
    }

    func test_verifyAction_multiple_actions() {
        let tester = TestWorkflow()
            .renderTester(initialState: .idle)

        let result = expectingFailures([
            "Received multiple actions in a single render test",
            "Received multiple outputs in a single render test",
        ]) {
            tester.render { rendering in
                rendering.doOutput("first")
                rendering.doOutput("second")
            }
        }

        expectingFailure(#"("sendOutput("second")") is not equal to ("noop(0)")"#) {
            result.assert(action: TestAction.noop(0))
        }

        expectingFailure("My own little action error") {
            result.verifyAction { (action: TestAction) in
                XCTAssertEqual(action, TestAction.sendOutput("nah"), "My own little action error")
            }
        }

        expectingFailure(#"Expected no action, but got sendOutput("second")"#) {
            result.assertNoAction()
        }
    }

    // MARK: Output

    func test_verifyOutput_output() {
        let result = TestWorkflow()
            .renderTester(initialState: .idle)
            .render { rendering in
                rendering.doOutput("hello")
            }

        expectingFailure(#"("string("hello")") is not equal to ("string("nope")")"#) {
            result.assert(output: .string("nope"))
        }

        expectingFailure("My own little output error") {
            result.verifyOutput { output in
                XCTAssertEqual(output, .string("goodbye"), "My own little output error")
            }
        }

        expectingFailure(#"Expected no output, but got string("hello")"#) {
            result.assertNoOutput()
        }
    }

    func test_verifyOutput_no_output() {
        let result = TestWorkflow()
            .renderTester(initialState: .idle)
            .render { _ in }

        expectingFailure("No output was produced") {
            result.assert(output: .string("nope"))
        }

        expectingFailure("No output was produced") {
            result.verifyOutput { output in
                XCTFail("Should not get called")
            }
        }
    }

    // MARK: State

    func test_verifyState() {
        let result = TestWorkflow()
            .renderTester(initialState: .idle)
            .render { _ in }

        expectingFailure("My own little state error") {
            result.verifyState { state in
                XCTAssertEqual(state, .sideEffect(key: "nah"), "My own little state error")
            }
        }
    }
}

private struct TestWorkflow: Workflow {
    enum Output: Equatable {
        case string(String)
    }

    enum State: Equatable {
        case idle
        case workflow(param: String, key: String = "")
        case voidWorkflow
        case sideEffect(key: String)
    }

    func makeInitialState() -> State {
        .idle
    }

    func render(state: State, context: RenderContext<TestWorkflow>) -> TestRendering {
        switch state {
        case .idle:
            break
        case .workflow(let param, let key):
            _ = TestChildWorkflow(input: param)
                .rendered(in: context, key: key)
        case .voidWorkflow:
            VoidWorkflow()
                .rendered(in: context)
        case .sideEffect(let key):
            context.runSideEffect(
                key: key,
                action: { _ in
                    XCTFail("Side effect should never be called")
                }
            )
        }

        let sink = context.makeSink(of: TestAction.self)

        return TestRendering(
            doNoopAction: { sink.send(.noop($0)) },
            doOutput: { sink.send(.sendOutput($0)) }
        )
    }
}

private enum TestAction: WorkflowAction, Equatable {
    case noop(Int)
    case sendOutput(String)

    typealias WorkflowType = TestWorkflow

    func apply(toState state: inout TestWorkflow.State) -> TestWorkflow.Output? {
        switch self {
        case .noop:
            return nil
        case .sendOutput(let string):
            return .string(string)
        }
    }
}

private struct TestRendering {
    var doNoopAction: (Int) -> Void
    var doOutput: (String) -> Void
}

private struct TestChildWorkflow: Workflow {
    var input: String
    func render(state: Void, context: RenderContext<Self>) -> String {
        XCTFail("Child workflow should never be called")
        return input
    }
}

private struct VoidWorkflow: Workflow {
    typealias State = Void
    typealias Rendering = Void
    func render(state: State, context: RenderContext<Self>) -> Rendering {
        ()
    }
}

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
        return expectingFailures([messageSubstring], file: file, line: line, perform: perform)
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

    override func record(_ issue: XCTIssue) {
        if let matchedIndex = expectedFailureStrings.firstIndex(where: { issue.compactDescription.contains($0) }) {
            expectedFailureStrings.remove(at: matchedIndex)
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

    // MARK: Workers

    func test_worker_missing() {
        let tester = TestWorkflow()
            .renderTester(initialState: .idle)
            .expect(
                worker: TestWorker(input: "input")
            )

        expectingFailure(#"Expected worker TestWorker(input: "input")"#) {
            tester.render { _ in }
        }
    }

    func test_worker_mismatch() {
        let tester = TestWorkflow()
            .renderTester(initialState: .worker(param: "actual"))
            .expect(
                worker: TestWorker(input: "expected")
            )

        expectingFailures([
            #"Unexpected worker during render TestWorker(input: "actual"). Expected TestWorker(input: "expected")."#,
            #"Expected worker TestWorker(input: "expected")"#,
        ]) {
            tester.render { _ in }
        }
    }

    func test_worker_unexpected() {
        let tester = TestWorkflow()
            .renderTester(initialState: .worker(param: "input"))

        expectingFailure(#"Unexpected worker during render TestWorker(input: "input")"#) {
            tester.render { _ in }
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
            result.verify(action: TestAction.noop(70))
        }

        expectingFailure("My own little action error") {
            result.verifyAction { (action: TestAction) in
                XCTAssertEqual(action, TestAction.sendOutput("nah"), "My own little action error")
            }
        }

        expectingFailure("Expected no action, but got noop(10)") {
            result.verifyNoAction()
        }
    }

    func test_verifyAction_no_action() {
        let result = TestWorkflow()
            .renderTester(initialState: .idle)
            .render { _ in }

        expectingFailure("No action was produced") {
            result.verify(action: TestAction.noop(1))
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
            result.verify(action: TestAction.noop(0))
        }

        expectingFailure("My own little action error") {
            result.verifyAction { (action: TestAction) in
                XCTAssertEqual(action, TestAction.sendOutput("nah"), "My own little action error")
            }
        }

        expectingFailure(#"Expected no action, but got sendOutput("second")"#) {
            result.verifyNoAction()
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
            result.verify(output: .string("nope"))
        }

        expectingFailure("My own little output error") {
            result.verifyOutput { output in
                XCTAssertEqual(output, .string("goodbye"), "My own little output error")
            }
        }

        expectingFailure(#"Expected no output, but got string("hello")"#) {
            result.verifyNoOutput()
        }
    }

    func test_verifyOutput_no_output() {
        let result = TestWorkflow()
            .renderTester(initialState: .idle)
            .render { _ in }

        expectingFailure("No output was produced") {
            result.verify(output: .string("nope"))
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

        expectingFailure(#"("idle") is not equal to ("worker(param: "wrong")")"#) {
            result.verify(state: .worker(param: "wrong"))
        }

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
        case worker(param: String)
        case workflow(param: String, key: String = "")
        case sideEffect(key: String)
    }

    func makeInitialState() -> State {
        return .idle
    }

    func render(state: State, context: RenderContext<TestWorkflow>) -> TestRendering {
        switch state {
        case .idle:
            break
        case .worker(let param):
            context.awaitResult(
                for: TestWorker(input: param),
                outputMap: { TestAction.sendOutput($0) }
            )
        case .workflow(let param, let key):
            _ = TestChildWorkflow(input: param)
                .rendered(in: context, key: key)
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

private struct TestWorker: Worker {
    var input: String

    typealias Output = String

    func run() -> SignalProducer<Output, Never> {
        XCTFail("Worker should never be called")
        return .empty
    }

    func isEquivalent(to otherWorker: TestWorker) -> Bool {
        return input == otherWorker.input
    }
}

private struct TestChildWorkflow: Workflow {
    var input: String
    func render(state: Void, context: RenderContext<Self>) -> String {
        XCTFail("Child workflow should never be called")
        return input
    }
}

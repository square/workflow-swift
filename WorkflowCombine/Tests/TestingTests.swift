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

import Combine
import Workflow
import WorkflowCombine
import WorkflowTesting
import XCTest

class WorkflowCombineTestingTests: XCTestCase {
    func test_workers() {
        let renderTester = TestWorkflow()
            .renderTester(initialState: .init(mode: .worker(input: "otherText"), output: ""))

        renderTester
            .expect(worker: TestWorker(input: "otherText"))
            .render { _ in }
    }

    func test_workerOutput_updatesState() {
        let renderTester = TestWorkflow()
            .renderTester(initialState: .init(mode: .worker(input: "otherText"), output: ""))

        renderTester
            .expect(
                worker: TestWorker(input: "otherText"),
                producingOutput: "otherText"
            )
            .render { _ in }
            .verifyState { state in
                XCTAssertEqual(state, TestWorkflow.State(mode: .worker(input: "otherText"), output: "otherText"))
            }
    }

    func test_worker_missing() {
        let tester = TestWorkflow()
            .renderTester()
            .expect(
                worker: TestWorker(input: "input")
            )

        expectingFailure(#"Expected child workflow of type: WorkerWorkflow<TestWorker>, key: """#) {
            tester.render { _ in }
        }
    }

    func test_worker_mismatch() {
        let tester = TestWorkflow()
            .renderTester(initialState: .init(mode: .worker(input: "test"), output: ""))
            .expect(
                worker: TestWorker(input: "not-test")
            )

        expectingFailures([
            #"Workers of type TestWorker not equivalent. Expected: TestWorker(input: "not-test"). Got: TestWorker(input: "test")"#,
        ]) {
            tester.render { _ in }
        }
    }

    func test_worker_unexpected() {
        let tester = TestWorkflow()
            .renderTester(initialState: .init(mode: .worker(input: "test"), output: ""))

        expectingFailure(#"Unexpected workflow of type WorkerWorkflow<TestWorker> with key """#) {
            tester.render { _ in }
        }
    }

    // MARK: - Failure Recording

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

    #if swift(>=5.3)

        // Undeprecated API on Xcode 12+ (which ships with Swift 5.3)
        override func record(_ issue: XCTIssue) {
            if removeFailure(withDescription: issue.compactDescription) {
                // Don’t forward the issue, it was expected
            } else {
                super.record(issue)
            }
        }

    #else

        // Otherwise, use old API
        override func recordFailure(withDescription description: String, inFile filePath: String, atLine lineNumber: Int, expected: Bool) {
            if removeFailure(withDescription: description) {
                // Don’t forward the failure, it was expected
            } else {
                super.recordFailure(withDescription: description, inFile: filePath, atLine: lineNumber, expected: expected)
            }
        }

    #endif
}

private struct TestWorkflow: Workflow {
    struct State: Equatable {
        enum Mode: Equatable {
            case idle
            case worker(input: String)
        }

        let mode: Mode
        var output: String
    }

    func makeInitialState() -> State {
        .init(mode: .idle, output: "")
    }

    func workflowDidChange(from previousWorkflow: TestWorkflow, state: inout State) {}

    func render(state: State, context: RenderContext<TestWorkflow>) {
        switch state.mode {
        case .idle:
            break
        case .worker(input: let input):
            TestWorker(input: input)
                .mapOutput { output in
                    AnyWorkflowAction {
                        $0.output = output
                        return nil
                    }
                }
                .running(in: context)
        }
    }
}

private struct TestWorker: Worker {
    let input: String

    func run() -> AnyPublisher<String, Never> {
        Just("").eraseToAnyPublisher()
    }

    func isEquivalent(to otherWorker: TestWorker) -> Bool {
        input == otherWorker.input
    }
}

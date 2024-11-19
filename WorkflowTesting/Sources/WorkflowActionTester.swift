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
import XCTest

extension WorkflowAction {
    /// Returns a state tester containing `self`.
    public static func tester(withState state: WorkflowType.State) -> WorkflowActionTester<WorkflowType, Self> {
        WorkflowActionTester(state: state)
    }
}

/// Testing helper that chains action sending and state/output assertions
/// to make tests easier to write.
///
/// ```
/// MyWorkflow.Action
///     .tester(withState: .firstState)
///     .send(action: .exampleAction)
///     .verifyOutput { output in
///         XCTAssertEqual(.finished, output)
///     }
///     .verifyState { state in
///         XCTAssertEqual(.differentState, state)
///     }
/// ```
///
/// Or to assert that an action produces no output:
///
/// ```
/// MyWorkflow.Action
///     .tester(withState: .firstState)
///     .send(action: .actionProducingNoOutput)
///     .assertNoOutput()
///     .verifyState { state in
///         XCTAssertEqual(.differentState, state)
///     }
/// ```
///
/// If your State or Output are `Equatable`, you can use the convenience assertion methods:
/// ```
/// MyWorkflow.Action
///     .tester(withState: .firstState)
///     .send(action: .exampleAction)
///     .assert(output: .finished)
///     .assert(state: .differentState)
/// ```
public struct WorkflowActionTester<WorkflowType, Action> where Action: WorkflowAction, Action.WorkflowType == WorkflowType {
    /// The current state
    let state: WorkflowType.State
    let output: WorkflowType.Output?

    /// Initializes a new state tester
    fileprivate init(state: WorkflowType.State, output: WorkflowType.Output? = nil) {
        self.state = state
        self.output = output
    }

    /// Sends an action to the reducer.
    ///
    /// - parameter action: The action to send.
    ///
    /// - returns: A new state tester containing the state and output (if any) after the update.
    @discardableResult
    public func send(action: Action) -> WorkflowActionTester<WorkflowType, Action> {
        var newState = state
        let output = action.apply(toState: &newState)
        return WorkflowActionTester(state: newState, output: output)
    }

    /// Asserts that the action produced no output
    ///
    /// - returns: A tester containing the current state and output.
    @discardableResult
    public func assertNoOutput(
        file: StaticString = #file,
        line: UInt = #line
    ) -> WorkflowActionTester<WorkflowType, Action> {
        if let output {
            XCTFail("Expected no output, but got \(output).", file: file, line: line)
        }
        return self
    }

    /// Invokes the given closure (which is intended to contain test assertions) with the produced output.
    /// If the previous action produced no output, the triggers a test failure and does not execute the closure.
    ///
    /// - parameter assertions: A closure that accepts a single output value.
    ///
    /// - returns: A tester containing the current state and output.
    @discardableResult
    public func verifyOutput(
        file: StaticString = #file,
        line: UInt = #line,
        _ assertions: (WorkflowType.Output) throws -> Void
    ) rethrows -> WorkflowActionTester<WorkflowType, Action> {
        guard let output else {
            XCTFail("No output was produced", file: file, line: line)
            return self
        }
        try assertions(output)
        return self
    }

    /// Invokes the given closure (which is intended to contain test assertions) with the current state.
    ///
    /// - parameter assertions: A closure that accepts a single state value.
    ///
    /// - returns: A tester containing the current state and output.
    @discardableResult
    public func verifyState(_ assertions: (WorkflowType.State) throws -> Void) rethrows -> WorkflowActionTester<WorkflowType, Action> {
        try assertions(state)
        return self
    }

    /// Invokes the given closure (which is intended to contain test assertions) with the current state.
    ///
    /// - parameter assertions: A closure that accepts a single state value.
    ///
    /// - returns: A tester containing the current state.
}

extension WorkflowActionTester where WorkflowType.State: Equatable {
    /// Triggers a test failure if the current state does not match the given expected state
    ///
    /// - Parameters:
    ///   - expectedState: The expected state
    /// - returns: A tester containing the current state and output.
    @discardableResult
    public func assert(state expectedState: WorkflowType.State, file: StaticString = #file, line: UInt = #line) -> WorkflowActionTester<WorkflowType, Action> {
        verifyState { actualState in
            XCTAssertEqual(actualState, expectedState, file: file, line: line)
        }
    }
}

extension WorkflowActionTester where WorkflowType.Output: Equatable {
    /// Triggers a test failure if the produced output does not match the given expected output
    ///
    /// - Parameters:
    ///   - expectedState: The expected output
    /// - returns: A tester containing the current state and output.
    @discardableResult
    public func assert(output expectedOutput: WorkflowType.Output, file: StaticString = #file, line: UInt = #line) -> WorkflowActionTester<WorkflowType, Action> {
        verifyOutput { actualOutput in
            XCTAssertEqual(actualOutput, expectedOutput, file: file, line: line)
        }
    }
}

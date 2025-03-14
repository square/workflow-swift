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

import CustomDump
import Workflow
import XCTest

/// The result of a `RenderTester` rendering. Used to verify state, output, and actions that were produced as a result of
/// actions performed during the render (such as child workflow output being produced).
public struct RenderTesterResult<WorkflowType: Workflow> {
    let initialState: WorkflowType.State
    let state: WorkflowType.State
    let appliedAction: AppliedAction<WorkflowType>?
    let output: WorkflowType.Output?

    init(
        initialState: WorkflowType.State,
        state: WorkflowType.State,
        appliedAction: AppliedAction<WorkflowType>?,
        output: WorkflowType.Output?
    ) {
        self.initialState = initialState
        self.state = state
        self.appliedAction = appliedAction
        self.output = output
    }

    /// Allows for assertions against the resulting state.
    @discardableResult
    public func verifyState(
        file: StaticString = #file,
        line: UInt = #line,
        assertions: (WorkflowType.State) throws -> Void
    ) rethrows -> RenderTesterResult<WorkflowType> {
        try assertions(state)
        return self
    }

    /// Asserts that no actions were produced
    @discardableResult
    public func assertNoAction(
        file: StaticString = #file,
        line: UInt = #line
    ) -> RenderTesterResult<WorkflowType> {
        if let appliedAction {
            XCTFail("Expected no action, but got \(appliedAction.erasedAction).", file: file, line: line)
        }
        return self
    }

    /// Allows for assertions agains the resulting action
    @discardableResult
    public func verifyAction<ActionType: WorkflowAction>(
        type: ActionType.Type = ActionType.self,
        file: StaticString = #file,
        line: UInt = #line,
        assertions: (ActionType) throws -> Void
    ) rethrows -> RenderTesterResult<WorkflowType> where ActionType.WorkflowType == WorkflowType {
        guard let appliedAction else {
            XCTFail("No action was produced", file: file, line: line)
            return self
        }
        try appliedAction.assert(file: file, line: line, assertions: assertions)
        return self
    }

    /// Asserts that the resulting action is equal to the given action.
    @discardableResult
    public func assert<ActionType: WorkflowAction>(
        action: ActionType,
        file: StaticString = #file,
        fileID: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> RenderTesterResult<WorkflowType> where ActionType.WorkflowType == WorkflowType, ActionType: Equatable {
        verifyAction(file: file, line: line) { appliedAction in
            expectNoDifference(
                appliedAction,
                action,
                "Action (First) does not match the expected action (Second)",
                fileID: fileID,
                filePath: file,
                line: line,
                column: column
            )
        }
    }

    /// Asserts that no output was produced.
    @discardableResult
    public func assertNoOutput(
        file: StaticString = #file,
        line: UInt = #line
    ) -> RenderTesterResult<WorkflowType> {
        if let output {
            XCTFail("Expected no output, but got \(output).", file: file, line: line)
        }
        return self
    }

    /// Allows for assertions agains the resulting output
    @discardableResult
    public func verifyOutput(
        file: StaticString = #file,
        line: UInt = #line,
        assertions: (WorkflowType.Output) throws -> Void
    ) rethrows -> RenderTesterResult<WorkflowType> {
        guard let output else {
            XCTFail("No output was produced", file: file, line: line)
            return self
        }
        try assertions(output)
        return self
    }
}

extension RenderTesterResult where WorkflowType.State: Equatable {
    /// Verifies that the resulting state is equal to the given state.
    @discardableResult
    public func assert(
        state expectedState: WorkflowType.State,
        file: StaticString = #file,
        fileID: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> RenderTesterResult<WorkflowType> {
        expectNoDifference(
            state,
            expectedState,
            "State (First) does not match the expected state (Second)",
            fileID: fileID,
            filePath: file,
            line: line,
            column: column
        )
        return self
    }

    /// Exhaustive state testing against the initial state.
    /// - Parameters:
    ///   - modifications: A function that receives the initial state
    ///   and is expected to mutate it to match the new state.
    @discardableResult
    public func assertStateModifications(
        file: StaticString = #file,
        line: UInt = #line,
        _ modifications: (inout WorkflowType.State) throws -> Void,
        fileID: StaticString = #fileID,
        column: UInt = #column
    ) rethrows -> RenderTesterResult<WorkflowType> {
        var initialState = initialState
        try modifications(&initialState)
        expectNoDifference(
            state,
            initialState,
            "State (First) does not match the expected state (Second)",
            fileID: fileID,
            filePath: file,
            line: line,
            column: column
        )
        return self
    }
}

extension RenderTesterResult where WorkflowType.Output: Equatable {
    /// Verifies that the resulting output is equal to the given output.
    @discardableResult
    public func assert(
        output expectedOutput: WorkflowType.Output,
        file: StaticString = #file,
        fileID: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> RenderTesterResult<WorkflowType> {
        verifyOutput(file: file, line: line) { output in
            expectNoDifference(
                output,
                expectedOutput,
                "Output (First) does not match the expected output (Second)",
                fileID: fileID,
                filePath: file,
                line: line,
                column: column
            )
        }
    }
}

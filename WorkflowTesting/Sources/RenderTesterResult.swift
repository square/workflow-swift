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

/// The result of a `RenderTester` rendering. Used to verify state, output, and actions that were produced as a result of
/// actions performed during the render (such as child workflow output being produced).
public final class RenderTesterResult<WorkflowType: Workflow> {
    let state: WorkflowType.State
    let appliedAction: AppliedAction<WorkflowType>?
    let output: WorkflowType.Output?

    internal init(state: WorkflowType.State, appliedAction: AppliedAction<WorkflowType>?, output: WorkflowType.Output?) {
        self.state = state
        self.appliedAction = appliedAction
        self.output = output
    }

    /// Allows for assertions against the resulting state.
    @discardableResult
    public func verifyState(
        file: StaticString = #file,
        line: UInt = #line,
        assertions: (WorkflowType.State) -> Void
    ) -> RenderTesterResult<WorkflowType> {
        assertions(state)
        return self
    }

    /// Verifies that no actions were produced
    @discardableResult
    public func verifyNoAction(
        file: StaticString = #file,
        line: UInt = #line
    ) -> RenderTesterResult<WorkflowType> {
        if let appliedAction = appliedAction {
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
        assertions: (ActionType) -> Void
    ) -> RenderTesterResult<WorkflowType> where ActionType.WorkflowType == WorkflowType {
        guard let appliedAction = appliedAction else {
            XCTFail("No action was produced", file: file, line: line)
            return self
        }
        appliedAction.assert(file: file, line: line, assertions: assertions)
        return self
    }

    /// Verifies that the resulting action is equal to the given action.
    @discardableResult
    public func verify<ActionType: WorkflowAction>(
        action: ActionType,
        file: StaticString = #file,
        line: UInt = #line
    ) -> RenderTesterResult<WorkflowType> where ActionType.WorkflowType == WorkflowType, ActionType: Equatable {
        return verifyAction(file: file, line: line) { appliedAction in
            XCTAssertEqual(appliedAction, action, file: file, line: line)
        }
    }

    /// Verifies that no output was produced.
    @discardableResult
    public func verifyNoOutput(
        file: StaticString = #file,
        line: UInt = #line
    ) -> RenderTesterResult<WorkflowType> {
        if let output = output {
            XCTFail("Expected no output, but got \(output).", file: file, line: line)
        }
        return self
    }

    /// Allows for assertions agains the resulting output
    @discardableResult
    public func verifyOutput(
        file: StaticString = #file,
        line: UInt = #line,
        assertions: (WorkflowType.Output) -> Void
    ) -> RenderTesterResult<WorkflowType> {
        guard let output = output else {
            XCTFail("No output was produced", file: file, line: line)
            return self
        }
        assertions(output)
        return self
    }
}

extension RenderTesterResult where WorkflowType.State: Equatable {
    /// Verifies that the resulting state is equal to the given state.
    @discardableResult
    public func verify(
        state expectedState: WorkflowType.State,
        file: StaticString = #file,
        line: UInt = #line
    ) -> RenderTesterResult<WorkflowType> {
        XCTAssertEqual(state, expectedState, file: file, line: line)
        return self
    }
}

extension RenderTesterResult where WorkflowType.Output: Equatable {
    /// Verifies that the resulting output is equal to the given output.
    @discardableResult
    public func verify(
        output expectedOutput: WorkflowType.Output,
        file: StaticString = #file,
        line: UInt = #line
    ) -> RenderTesterResult<WorkflowType> {
        return verifyOutput(file: file, line: line) { output in
            XCTAssertEqual(output, expectedOutput, file: file, line: line)
        }
    }
}

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
import IssueReporting
import XCTest

@testable import Workflow

extension WorkflowAction {
    /// Returns a `WorkflowActionTester` with the given state before the `WorkflowAction` has been applied to it.
    ///
    /// - Parameters:
    ///   - state: The `WorkflowType.State` instance that specifies the state before the `WorkflowAction` has been applied.
    ///   - workflow: An optional `WorkflowType` instance to be used if the `WorkflowAction` needs to read workflow properties off of the `ApplyContext` parameter during action application. If this parameter is unspecified, attempts to access the `WorkflowType`'s properties will error in the testing runtime.
    /// - Returns: An appropriately-configured `WorkflowActionTester`.
    public static func tester(
        withState state: WorkflowType.State,
        workflow: WorkflowType? = nil
    ) -> WorkflowActionTester<WorkflowType, Self> {
        WorkflowActionTester(
            state: state,
            context: TestApplyContext(
                kind: workflow.map { .workflow($0) } ?? .expectations([:])
            )
        )
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
///
/// If the `Action` under test uses the runtime's `ApplyContext` to read values from the
/// current `Workflow` instance, then an instance of the `Workflow` with the expected
/// properties that will be read during `send(action:)` must be supplied like:
/// ```
/// MyWorkflow.Action
///     .tester(
///         withState: .firstState,
///         workflow: MyWorkflow(prop: 42)
///     )
///     .send(action: .exampleActionThatReadsWorkflowProp)
///     .assert(...)
/// ```
public struct WorkflowActionTester<WorkflowType, Action: WorkflowAction> where Action.WorkflowType == WorkflowType {
    /// The current state
    let state: WorkflowType.State
    let output: WorkflowType.Output?
    let context: TestApplyContext<WorkflowType>

    /// Initializes a new state tester
    fileprivate init(
        state: WorkflowType.State,
        context: TestApplyContext<WorkflowType>,
        output: WorkflowType.Output? = nil
    ) {
        self.state = state
        self.context = context
        self.output = output
    }

    /// Sends an action to the reducer.
    ///
    /// - parameter action: The action to send.
    ///
    /// - returns: A new state tester containing the state and output (if any) after the update.
    @discardableResult
    public func send(action: Action) -> WorkflowActionTester<WorkflowType, Action>
        where Action.WorkflowType == WorkflowType
    {
        var newState = state
        let wrappedContext = ApplyContext.make(implementation: context)
        let output = action.apply(toState: &newState, context: wrappedContext)

        return WorkflowActionTester(state: newState, context: context, output: output)
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
            reportIssue("Expected no output, but got \(output).", filePath: file, line: line)
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
            reportIssue("No output was produced", filePath: file, line: line)
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
    public func verifyState(
        _ assertions: (WorkflowType.State) throws -> Void
    ) rethrows -> WorkflowActionTester<WorkflowType, Action> {
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
            expectNoDifference(actualState, expectedState, filePath: file, line: line)
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
            expectNoDifference(actualOutput, expectedOutput, filePath: file, line: line)
        }
    }
}

// MARK: - ApplyContext

struct TestApplyContext<Wrapped: Workflow>: ApplyContextType {
    enum TestContextKind {
        case workflow(Wrapped)
        // FIXME: flesh this out to support 'just in time' values
        // rather than requiring a full Workflow instance to be provided
        // https://github.com/square/workflow-swift/issues/351
        case expectations([AnyKeyPath: Any])
    }

    var storage: TestContextKind

    init(kind: TestContextKind) {
        self.storage = kind
    }

    subscript<Value>(
        workflowValue keyPath: KeyPath<Wrapped, Value>
    ) -> Value {
        switch storage {
        case .workflow(let workflow):
            return workflow[keyPath: keyPath]
        case .expectations(var expectedValues):
            guard
                // We have an expected value
                let value = expectedValues.removeValue(forKey: keyPath),
                // And it's the right type
                let value = value as? Value
            else {
                // We're expecting a value of optional type. Error, but don't crash
                // since we can just return nil.
                if Value.self is OptionalProtocol.Type {
                    reportIssue("Attempted to read value \(keyPath as AnyKeyPath), when applying an action, but no value was present. Pass an instance of the Workflow to the ActionTester to enable this functionality.")
                    return Any?.none as! Value
                } else {
                    fatalError("Attempted to read value \(keyPath as AnyKeyPath), when applying an action, but no value was present. Pass an instance of the Workflow to the ActionTester to enable this functionality.")
                }
            }
            return value
        }
    }
}

private protocol OptionalProtocol {}
extension Optional: OptionalProtocol {}

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

/// Conforming types represent an action that advances a workflow. When applied, an action emits the next
/// state and / or output for the workflow.
public protocol WorkflowAction<WorkflowType> {
    /// The type of workflow that this action can be applied to.
    associatedtype WorkflowType: Workflow

    /// Applies this action to a given state of the workflow, optionally returning an output event.
    ///
    /// - Parameter state: The current state of the workflow. The state is passed as an `inout` param, allowing actions
    ///                    to modify state during application.
    ///
    /// - Returns: An optional output event for the workflow. If an output event is returned, it will be passed up
    ///            the workflow hierarchy to this workflow's parent.
    func apply(toState state: inout WorkflowType.State) -> WorkflowType.Output?
}

/// A type-erased workflow action.
///
/// The `AnyWorkflowAction` type forwards `apply` to an underlying workflow action, hiding its specific underlying type.
public struct AnyWorkflowAction<WorkflowType: Workflow>: WorkflowAction {
    private let _apply: (inout WorkflowType.State) -> WorkflowType.Output?

    /// The underlying type-erased `WorkflowAction`
    public let base: Any

    /// True iff the underlying `apply` implementation is defined by a closure vs wrapping a `WorkflowAction` conformance
    public let isClosureBased: Bool

    /// Creates a type-erased workflow action that wraps the given instance.
    ///
    /// - Parameter base: A workflow action to wrap.
    public init<E>(_ base: E) where E: WorkflowAction, E.WorkflowType == WorkflowType {
        if let anyEvent = base as? AnyWorkflowAction<WorkflowType> {
            self = anyEvent
            return
        }
        self._apply = { return base.apply(toState: &$0) }
        self.base = base
        self.isClosureBased = false
    }

    /// Creates a type-erased workflow action with the given `apply` implementation.
    ///
    /// - Parameter apply: the apply function for the resulting action.
    public init(
        _ apply: @escaping (inout WorkflowType.State) -> WorkflowType.Output?,
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) {
        let closureAction = ClosureAction<WorkflowType>(
            _apply: apply,
            fileID: fileID,
            line: line
        )
        self.init(closureAction: closureAction)
    }

    /// Private initializer forwarded to via `init(_ apply:...)`
    /// - Parameter closureAction: The `ClosureAction` wrapping the underlying `apply` closure.
    fileprivate init(closureAction: ClosureAction<WorkflowType>) {
        self._apply = closureAction.apply(toState:)
        self.base = closureAction
        self.isClosureBased = true
    }

    public func apply(toState state: inout WorkflowType.State) -> WorkflowType.Output? {
        return _apply(&state)
    }
}

extension AnyWorkflowAction {
    /// Creates a type-erased workflow action that simply sends the given output event.
    ///
    /// - Parameter output: The output event to send when this action is applied.
    public init(sendingOutput output: WorkflowType.Output) {
        self = AnyWorkflowAction { state in
            output
        }
    }

    /// Creates a type-erased workflow action that does nothing (it leaves state unchanged and does not emit an output
    /// event).
    public static var noAction: AnyWorkflowAction<WorkflowType> {
        return AnyWorkflowAction { state in
            nil
        }
    }
}

// MARK: Closure Action

/// A `WorkflowAction` that wraps an `apply(...)` implementation defined by a closure.
/// Mainly used to provide more useful debugging/telemetry information for `AnyWorkflow` instances
/// defined via a closure.
struct ClosureAction<WorkflowType: Workflow>: WorkflowAction {
    private let _apply: (inout WorkflowType.State) -> WorkflowType.Output?
    let fileID: StaticString
    let line: UInt

    init(
        _apply: @escaping (inout WorkflowType.State) -> WorkflowType.Output?,
        fileID: StaticString,
        line: UInt
    ) {
        self._apply = _apply
        self.fileID = fileID
        self.line = line
    }

    func apply(toState state: inout WorkflowType.State) -> WorkflowType.Output? {
        _apply(&state)
    }
}

extension ClosureAction: CustomStringConvertible {
    var description: String {
        "\(Self.self)(fileID: \(fileID), line: \(line))"
    }
}

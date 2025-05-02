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
    func apply(
        toState state: inout WorkflowType.State,
        context: ActionContext<WorkflowType.Props>
    ) -> WorkflowType.Output?
}

/// A type-erased workflow action.
///
/// The `AnyWorkflowAction` type forwards `apply` to an underlying workflow action, hiding its specific underlying type.
public struct AnyWorkflowAction<WorkflowType: Workflow>: WorkflowAction {
    public typealias ActionApply = (
        inout WorkflowType.State,
        ActionContext<WorkflowType.Props>
    ) -> WorkflowType.Output?

    private let _apply: ActionApply

    /// The underlying type-erased `WorkflowAction`
    public let base: Any

    /// True iff the underlying `apply` implementation is defined by a closure vs wrapping a `WorkflowAction` conformance
    public let isClosureBased: Bool

    /// Creates a type-erased workflow action that wraps the given instance.
    ///
    /// - Parameter base: A workflow action to wrap.
    public init<E: WorkflowAction>(_ base: E) where E.WorkflowType == WorkflowType {
        if let anyEvent = base as? AnyWorkflowAction<WorkflowType> {
            self = anyEvent
            return
        }
        self._apply = {
            base.apply(toState: &$0, context: $1)
        }
        self.base = base
        self.isClosureBased = false
    }

    /// Creates a type-erased workflow action with the given `apply` implementation.
    ///
    /// - Parameter apply: the apply function for the resulting action.
    public init(
        _ apply: @escaping ActionApply,
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

    // TODO: backwards compatible init if you don't use the param?
    public init(
        _ apply: @escaping (inout WorkflowType.State) -> WorkflowType.Output?,
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) {
        self.init(
            { state, _ in apply(&state) },
            fileID: fileID,
            line: line
        )
    }

    /// Private initializer forwarded to via `init(_ apply:...)`
    /// - Parameter closureAction: The `ClosureAction` wrapping the underlying `apply` closure.
    fileprivate init(closureAction: ClosureAction<WorkflowType>) {
        self._apply = closureAction.apply(toState:context:)
        self.base = closureAction
        self.isClosureBased = true
    }

    public func apply(
        toState state: inout WorkflowType.State,
        context: ActionContext<WorkflowType.Props>
    ) -> WorkflowType.Output? {
        _apply(&state, context)
    }
}

extension AnyWorkflowAction {
    /// Creates a type-erased workflow action that simply sends the given output event.
    ///
    /// - Parameter output: The output event to send when this action is applied.
    public init(sendingOutput output: WorkflowType.Output) {
        self = AnyWorkflowAction { _, _ in
            output
        }
    }

    /// Creates a type-erased workflow action that does nothing (it leaves state unchanged and does not emit an output
    /// event).
    public static var noAction: AnyWorkflowAction<WorkflowType> {
        AnyWorkflowAction { _, _ in
            nil
        }
    }
}

// MARK: Closure Action

/// A `WorkflowAction` that wraps an `apply(...)` implementation defined by a closure.
/// Mainly used to provide more useful debugging/telemetry information for `AnyWorkflow` instances
/// defined via a closure.
struct ClosureAction<WorkflowType: Workflow>: WorkflowAction {
    typealias ActionApply = (
        inout WorkflowType.State,
        ActionContext<WorkflowType.Props>
    ) -> WorkflowType.Output?

    private let _apply: ActionApply
    let fileID: StaticString
    let line: UInt

    init(
        _apply: @escaping ActionApply,
        fileID: StaticString,
        line: UInt
    ) {
        self._apply = _apply
        self.fileID = fileID
        self.line = line
    }

    func apply(
        toState state: inout WorkflowType.State,
        context: ActionContext<WorkflowType.Props>
    ) -> WorkflowType.Output? {
        _apply(&state, context)
    }
}

extension ClosureAction: CustomStringConvertible {
    var description: String {
        "\(Self.self)(fileID: \(fileID), line: \(line))"
    }
}

// MARK: - experimental API

final class Storage<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}

extension Storage: Equatable where Value: Equatable {
    static func == (lhs: Storage<Value>, rhs: Storage<Value>) -> Bool {
        lhs.value == rhs.value
    }
}

extension Storage: Hashable where Value: Hashable {
    var hashValue: Int { value.hashValue }
    func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

import Foundation

private struct OnAccess: Hashable {
    let id: UUID = .init()
    let onAccess: (() -> Void)?

    func callAsFunction() { onAccess?() }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

protocol ActionContextType<WorkflowType> {
    associatedtype WorkflowType: Workflow

    subscript<Property>(
        props keyPath: KeyPath<WorkflowType.Props, Property>
    ) -> Property { get }
}

extension ActionContext: ActionContextType {}

struct ConcreteActionContext<WorkflowType: Workflow>: ActionContextType {
    let storage: Storage<WorkflowType>

    init(
        _ value: WorkflowType
    ) {
        self.storage = Storage(value)
    }

    init(storage: Storage<WorkflowType>) {
        self.storage = storage
    }

    public subscript<Property>(
        props keyPath: KeyPath<WorkflowType.Props, Property>
    ) -> Property {
        storage.value[keyPath: keyPath]
    }
}

// TODO: rename to 'ApplyContext' for `RenderContext` symmetry?
public struct ActionContext<WorkflowType: Workflow> {
    let impl: any ActionContextType<WorkflowType>

    init<Impl: ActionContextType>(impl: Impl)
        where Impl.WorkflowType == WorkflowType
    {
        self.impl = impl
    }

    public subscript<Property>(
        props keyPath: KeyPath<WorkflowType.Props, Property>
    ) -> Property {
        impl[props: keyPath]
    }
}

extension ActionContext {
    static func make<Wrapped: ActionContextType>(
        implementation: Wrapped
    ) -> ActionContext<Wrapped.WorkflowType> where Wrapped.WorkflowType == WorkflowType {
        let ret = ActionContext(impl: implementation)
        return ret
    }
}

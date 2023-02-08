/*
 * Copyright 2022 Square Inc.
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

import Foundation

// MARK: - WorkflowObserver

/// The `WorkflowObserver` protocol provides an interface to receive updates during the runtime's
/// execution loop. All requirements are optional, and no-ops are provided by default.
public protocol WorkflowObserver {
    /// Indicates the start of a `WorkflowSession`, which tracks the life of the underlying `WorkflowNode` used to provide renderings for a given `Workflow` type and rendering key.
    /// - Parameter session: The `WorkflowSession` that began.
    func sessionDidBegin(
        _ session: WorkflowSession
    )

    /// Marks the end of a `WorkflowSession`, indicating that the corresponding `WorkflowNode` has been removed from the tree of Workflows.
    /// - Parameter session: The `WorkflowSession` that ended.
    func sessionDidEnd(
        _ session: WorkflowSession
    )

    /// Indicates a `Workflow` produced its initial state value.
    /// - Parameters:
    ///   - workflow: The `Workflow` that just produced its initial state.
    ///   - initialState: The `State` that was created.
    ///   - session: The `WorkflowSession` corresponding to the backing `WorkflowNode`
    func workflowDidMakeInitialState<WorkflowType: Workflow>(
        _ workflow: WorkflowType,
        initialState: WorkflowType.State,
        session: WorkflowSession
    )

    /// Called before a `Workflow` is queried for its latest `Rendering`.
    /// - Parameters:
    ///   - workflow: The `Workflow` that is about to be render.
    ///   - state: The corresponding `State` that will be used during the render call.
    ///   - session: The `WorkflowSession` corresponding to the backing `WorkflowNode`.
    /// - Returns: An optional closure to be called immediately after the new `Rendering` is produced, which takes the rendering as the only parameter.
    func workflowWillRender<WorkflowType: Workflow>(
        _ workflow: WorkflowType,
        state: WorkflowType.State,
        session: WorkflowSession
    ) -> ((WorkflowType.Rendering) -> Void)?

    /// Called after an existing `Workflow` is updated.
    /// - Parameters:
    ///   - oldWorkflow: The previous `Workflow`
    ///   - newWorkflow: The new `Workflow`
    ///   - state: The state **after** the update has occurred.
    ///   - session: The `WorkflowSession` corresponding to the backing `WorkflowNode`.
    func workflowDidChange<WorkflowType: Workflow>(
        from oldWorkflow: WorkflowType,
        to newWorkflow: WorkflowType,
        state: WorkflowType.State,
        session: WorkflowSession
    )

    /// Called after a `WorkflowAction` is received, but **before** it has been handled and propagated up the tree.
    /// - Parameters:
    ///   - action: The action that was received.
    ///   - session: The `WorkflowSession` corresponding to the backing `WorkflowNode`.
    func workflowDidReceiveAction<Action: WorkflowAction>(
        _ action: Action,
        workflow: Action.WorkflowType,
        session: WorkflowSession
    )

    /// Called when a `WorkflowAction` will be applied to its corresponding Workflow's State
    /// - Parameters:
    ///   - action: The action that will be applied.
    ///   - workflow: The action's corresponding `Workflow`.
    ///   - state: The state to which the action will be applied.
    ///   - session: The `WorkflowSession` corresponding to the backing `WorkflowNode`.
    /// - Returns: An optional closure to be called immediately after the action is applied to the `State`, and an optional `Output` has been produced. The closure takes the updated state and optional output as its arguments.
    func workflowWillApplyAction<Action: WorkflowAction>(
        _ action: Action,
        workflow: Action.WorkflowType,
        state: Action.WorkflowType.State,
        session: WorkflowSession
    ) -> ((Action.WorkflowType.State, Action.WorkflowType.Output?) -> Void)?
}

// MARK: - WorkflowSession

/// A `WorkflowSession`encapsulates the information that gives a `WorkflowNode` its identity.
/// In particular, it captures:
/// - The type of the corresponding `Workflow` conformance.
/// - The `String` key used when the workflow was rendered.
/// - An `Identifier` type that is unique across program execution.
/// - An optional reference to a parent `WorkflowSession`, to differentiate root nodes.
public struct WorkflowSession {
    public struct Identifier: Hashable {
        private static var _nextRawID: UInt64 = 0
        private static func _makeNextSessionID() -> UInt64 {
            let nextID = _nextRawID
            _nextRawID += 1
            return nextID
        }

        let rawIdentifier: UInt64 = Self._makeNextSessionID()
    }

    /// As structs cannot contain stored properties of their own type, we use an indirect enum
    /// to allow referencing the parent session.
    private indirect enum IndirectParent {
        case some(WorkflowSession)
        case none

        init(_ parent: WorkflowSession?) {
            switch parent {
            case .some(let value):
                self = .some(value)
            case .none:
                self = .none
            }
        }
    }

    public let workflowType: Any.Type

    public let renderKey: String

    public let sessionID = Identifier()

    private let _indirectParent: IndirectParent
    public var parent: WorkflowSession? {
        switch _indirectParent {
        case .some(let parent):
            return parent
        case .none:
            return nil
        }
    }

    /// Creates a new `WorkflowSession` instance. Note, construction of this type
    /// is not safe to perform concurrently with respect to other instance initialization.
    /// - Parameters:
    ///   - workflow: The associated `Workflow` instance
    ///   - renderKey: The string key used to render `workflow`
    ///   - parent: The parent Workflow's session, if any
    init<WorkflowType: Workflow>(
        workflow: WorkflowType,
        renderKey: String,
        parent: WorkflowSession?
    ) {
        self.workflowType = WorkflowType.self
        self.renderKey = renderKey
        self._indirectParent = IndirectParent(parent)
    }
}

// MARK: - No-op Defaults

public extension WorkflowObserver {
    func sessionDidBegin(
        _ session: WorkflowSession
    ) {}

    func sessionDidEnd(
        _ session: WorkflowSession
    ) {}

    func workflowDidMakeInitialState<WorkflowType: Workflow>(
        _ workflow: WorkflowType,
        initialState: WorkflowType.State,
        session: WorkflowSession
    ) {}

    func workflowWillRender<WorkflowType: Workflow>(
        _ workflow: WorkflowType,
        state: WorkflowType.State,
        session: WorkflowSession
    ) -> ((WorkflowType.Rendering) -> Void)? { nil }

    func workflowDidChange<WorkflowType: Workflow>(
        from oldWorkflow: WorkflowType,
        to newWorkflow: WorkflowType,
        state: WorkflowType.State,
        session: WorkflowSession
    ) {}

    func workflowDidReceiveAction<Action: WorkflowAction>(
        _ action: Action,
        workflow: Action.WorkflowType,
        session: WorkflowSession
    ) {}

    func workflowWillApplyAction<Action: WorkflowAction>(
        _ action: Action,
        workflow: Action.WorkflowType,
        state: Action.WorkflowType.State,
        session: WorkflowSession
    ) -> ((Action.WorkflowType.State, Action.WorkflowType.Output?) -> Void)? { nil }
}

// MARK: Chained Observer

/// 'Chained' observer implementation, which multiplexes a list of `WorkflowObservers` into a
/// single observer interface.
final class ChainedWorkflowObserver: WorkflowObserver {
    let observers: [WorkflowObserver]

    init(observers: [WorkflowObserver]) {
        self.observers = observers
    }

    func sessionDidBegin(_ session: WorkflowSession) {
        for observer in observers {
            observer.sessionDidBegin(session)
        }
    }

    func sessionDidEnd(_ session: WorkflowSession) {
        for observer in observers {
            observer.sessionDidEnd(session)
        }
    }

    func workflowDidMakeInitialState<WorkflowType>(_ workflow: WorkflowType, initialState: WorkflowType.State, session: WorkflowSession) where WorkflowType: Workflow {
        for observer in observers {
            observer.workflowDidMakeInitialState(workflow, initialState: initialState, session: session)
        }
    }

    func workflowWillRender<WorkflowType>(
        _ workflow: WorkflowType,
        state: WorkflowType.State,
        session: WorkflowSession
    ) -> ((WorkflowType.Rendering) -> Void)? where WorkflowType: Workflow {
        let callbacks = observers.compactMap {
            $0.workflowWillRender(workflow, state: state, session: session)
        }

        guard !callbacks.isEmpty else {
            return nil
        }

        // Invoke the callbacks in reverse order.
        // This enables the first observer to 'bookend' the method and
        // other observer callbacks, which can useful if trying to implement
        // performance tracing instrumentation.
        return { rendering in
            for callback in callbacks.reversed() {
                callback(rendering)
            }
        }
    }

    func workflowDidChange<WorkflowType>(
        from oldWorkflow: WorkflowType,
        to newWorkflow: WorkflowType,
        state: WorkflowType.State,
        session: WorkflowSession
    ) where WorkflowType: Workflow {
        for observer in observers {
            observer.workflowDidChange(
                from: oldWorkflow,
                to: newWorkflow,
                state: state,
                session: session
            )
        }
    }

    func workflowDidReceiveAction<Action>(
        _ action: Action,
        workflow: Action.WorkflowType,
        session: WorkflowSession
    ) where Action: WorkflowAction {
        for observer in observers {
            observer.workflowDidReceiveAction(
                action,
                workflow: workflow,
                session: session
            )
        }
    }

    func workflowWillApplyAction<Action>(
        _ action: Action,
        workflow: Action.WorkflowType,
        state: Action.WorkflowType.State,
        session: WorkflowSession
    ) -> ((Action.WorkflowType.State, Action.WorkflowType.Output?) -> Void)? where Action: WorkflowAction {
        let callbacks = observers.compactMap {
            $0.workflowWillApplyAction(
                action,
                workflow: workflow,
                state: state,
                session: session
            )
        }

        guard !callbacks.isEmpty else {
            return nil
        }

        // Invoke the callbacks in reverse order.
        // This enables the first observer to 'bookend' the method and
        // other observer callbacks, which can useful if trying to implement
        // performance tracing instrumentation.
        return { state, output in
            for callback in callbacks.reversed() {
                callback(state, output)
            }
        }
    }
}

extension Array where Element == WorkflowObserver {
    func chained() -> WorkflowObserver? {
        if count <= 1 {
            // no wrapping needed if empty or a single element
            return first
        } else {
            return ChainedWorkflowObserver(observers: self)
        }
    }
}

// MARK: - Global Observation (SPI)

@_spi(WorkflowGlobalObservation)
public protocol ObserversInterceptor {
    /// Provides a single access point to provide the final list of `WorkflowObserver` used by the runtime.
    /// This may be used to ensure a known set of observers is used in a particular order for all
    /// `WorkflowHost`s created over the life of a program.
    /// - Parameter initialObservers: Array of observers passed to a `WorkflowHost` constructor
    /// - Returns: The array of `WorkflowObserver`s to be used by the `WorkflowHost`
    func workflowObservers(for initialObservers: [WorkflowObserver]) -> [WorkflowObserver]
}

@_spi(WorkflowGlobalObservation)
public enum WorkflowObservation {
    private static var _sharedInterceptorStorage: ObserversInterceptor = NoOpObserversInterceptor()

    /// The `DefaultObserversProvider` used by all runtimes.
    public static var sharedObserversInterceptor: ObserversInterceptor! {
        get {
            _sharedInterceptorStorage
        }
        set {
            guard newValue != nil else {
                _sharedInterceptorStorage = NoOpObserversInterceptor()
                return
            }

            _sharedInterceptorStorage = newValue
        }
    }

    private struct NoOpObserversInterceptor: ObserversInterceptor {
        func workflowObservers(for initialObservers: [WorkflowObserver]) -> [WorkflowObserver] {
            initialObservers
        }
    }
}

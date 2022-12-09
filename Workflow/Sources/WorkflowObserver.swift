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

public protocol WorkflowObserver {
    func sessionDidBegin(
        _ session: WorkflowSession
    )

    func sessionDidEnd(
        _ session: WorkflowSession
    )

    func workflowDidMakeInitialState<WorkflowType: Workflow>(
        _ workflow: WorkflowType,
        initialState: WorkflowType.State,
        session: WorkflowSession
    )

    func workflowWillRender<WorkflowType: Workflow>(
        _ workflow: WorkflowType,
        state: WorkflowType.State,
        session: WorkflowSession
    ) -> ((WorkflowType.Rendering) -> Void)?

    func workflowWillChange<WorkflowType: Workflow>(
        from oldWorkflow: WorkflowType,
        to newWorkflow: WorkflowType,
        state: WorkflowType.State,
        session: WorkflowSession
    ) -> ((WorkflowType.State) -> Void)?

    func workflowDidReceiveAction<Action: WorkflowAction>(
        _ action: Action,
        workflow: Action.WorkflowType,
        session: WorkflowSession
    )
}

// example impl
final class WorkflowObserverImpl: WorkflowObserver {
    func sessionDidBegin(_ session: WorkflowSession) {
        print("session did begin")
    }

    func sessionDidEnd(_ session: WorkflowSession) {
        print("session did end")
    }

    func workflowDidMakeInitialState<WorkflowType>(_ workflow: WorkflowType, initialState: WorkflowType.State, session: WorkflowSession) where WorkflowType: Workflow {
        print("did make initial state")
    }

    func workflowWillRender<WorkflowType>(_ workflow: WorkflowType, state: WorkflowType.State, session: WorkflowSession) -> ((WorkflowType.Rendering) -> Void)? where WorkflowType: Workflow {
        print("will render")
        return { _ in
            print("did render")
        }
    }

    func workflowDidChange<WorkflowType>(from oldWorkflow: WorkflowType, to newWorkflow: WorkflowType, state: WorkflowType.State, session: WorkflowSession) where WorkflowType: Workflow {
        print("did change")
    }

    func workflowDidReceiveAction<Action>(_ action: Action, workflow: Action.WorkflowType, session: WorkflowSession) where Action: WorkflowAction {
        print("on action sent")
    }

    func workflowWillApplyAction<WorkflowType, Action>(_ action: Action, workflow: WorkflowType, state: Action.WorkflowType.State, session: WorkflowSession) -> ((WorkflowType.State) -> Void)? where WorkflowType == Action.WorkflowType, Action: WorkflowAction {
        print("will apply action")
        return { _ in
            print("did apply action")
        }
    }
}

// MARK: - WorkflowSession

public struct WorkflowSession {
    public struct Identifier: Hashable {
        private static var _nextRawID: UInt64 = 0
        private static func _makeNextSessionID() -> UInt64 {
            _nextRawID += 1
            return _nextRawID
        }

        let rawIdentifier: UInt64 = Self._makeNextSessionID()
    }

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

    // pseudo-one-shot before/after render hook
    func workflowWillRender<WorkflowType: Workflow>(
        _ workflow: WorkflowType,
        state: WorkflowType.State,
        session: WorkflowSession
    ) -> ((WorkflowType.Rendering) -> Void)? { nil }

    // is just providing the state after update sufficient?
    func workflowWillChange<WorkflowType: Workflow>(
        from oldWorkflow: WorkflowType,
        to newWorkflow: WorkflowType,
        state: WorkflowType.State,
        session: WorkflowSession
    ) -> ((WorkflowType.State) -> Void)? { nil }

    func onActionSent<Action: WorkflowAction>(
        action: Action,
        session: WorkflowSession
    ) {}

    func workflowDidReceiveAction<Action: WorkflowAction>(
        _ action: Action,
        workflow: Action.WorkflowType,
        session: WorkflowSession
    ) {}
}

// MARK: Chained Observer

final class ChainedWorkflowObserver: WorkflowObserver {
    private let observers: [WorkflowObserver]

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

        return { rendering in
            for callback in callbacks.reversed() {
                callback(rendering)
            }
        }
    }

    func workflowWillChange<WorkflowType>(
        from oldWorkflow: WorkflowType,
        to newWorkflow: WorkflowType,
        state: WorkflowType.State,
        session: WorkflowSession
    ) -> ((WorkflowType.State) -> Void)? where WorkflowType: Workflow {
        let callbacks = observers.compactMap {
            $0.workflowWillChange(
                from: oldWorkflow,
                to: newWorkflow,
                state: state,
                session: session
            )
        }

        guard !callbacks.isEmpty else {
            return nil
        }

        return { state in
            for callback in callbacks.reversed() {
                callback(state)
            }
        }
    }

    func workflowDidReceiveAction<Action>(_ action: Action, workflow: Action.WorkflowType, session: WorkflowSession) where Action: WorkflowAction {
        for observer in observers {
            observer.workflowDidReceiveAction(
                action,
                workflow: workflow,
                session: session
            )
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

// MARK: Example Observers

public protocol LoggableAction {
    var loggingDescription: String { get }
}

public struct SimpleActionLogger: WorkflowObserver {
    let log: (String) -> Void = {
        print($0)
    }

    public init() {}

    public func workflowDidReceiveAction<Action>(_ action: Action, workflow: Action.WorkflowType, session: WorkflowSession) where Action: WorkflowAction {
        switch action {
        case let action as LoggableAction:
            // TODO: maybe there is a way to avoid dynamic casting
            log("got loggable action: \(action.loggingDescription)")
        default:
            log("got default action: \(String(describing: action))")
        }
    }
}

// counts number of nodes created over time (in a single tree)
public final class SimpleSessionCounter: WorkflowObserver {
    var sessionCount = 0

    public init() {}

    public func sessionDidBegin(_ session: WorkflowSession) {
        sessionCount += 1
        print("session count: \(sessionCount)")
    }
}

public final class SimpleRenderTimingObserver: WorkflowObserver {
    public init() {}

    public func workflowWillRender<WorkflowType>(_ workflow: WorkflowType, state: WorkflowType.State, session: WorkflowSession) -> ((WorkflowType.Rendering) -> Void)? where WorkflowType: Workflow {
        let start = CACurrentMediaTime()

        let onRenderComplete = { (rendering: WorkflowType.Rendering) in
            let end = CACurrentMediaTime()
            let renderTime = end - start
            let timingMillis = renderTime / 1000
            print("render of node: \(session.sessionID) completed in \(timingMillis) ms")
        }

        return onRenderComplete
    }
}

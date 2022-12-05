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

    // pseudo-one-shot before/after render hook
    func workflowWillRender<WorkflowType: Workflow>(
        _ workflow: WorkflowType,
        state: WorkflowType.State,
        session: WorkflowSession
    ) -> ((WorkflowType.Rendering) -> Void)?

    // is just providing the state after update sufficient?
    func workflowDidChange<WorkflowType: Workflow>(
        from oldWorkflow: WorkflowType,
        to newWorkflow: WorkflowType,
        state: WorkflowType.State,
        session: WorkflowSession
    )

    func onActionSent<Action: WorkflowAction>(
        action: Action,
        session: WorkflowSession
    )

    func workflowWillApplyAction<WorkflowType, Action: WorkflowAction>(
        _ action: Action,
        workflow: WorkflowType,
        state: Action.WorkflowType.State,
        session: WorkflowSession
    ) -> ((WorkflowType.State) -> Void)? where Action.WorkflowType == WorkflowType
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

    func onActionSent<Action>(action: Action, session: WorkflowSession) where Action: WorkflowAction {
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

public class WorkflowSession {
    private static var _nextID: UInt64 = 0
    static func makeSessionID() -> UInt64 {
        _nextID += 1
        return _nextID
    }

    public let typeDescriptor: String

    public let renderKey: String

    public let sessionID: UInt64

    public let parent: WorkflowSession?

    init<WorkflowType: Workflow>(
        workflow: WorkflowType,
        renderKey: String,
        parent: WorkflowSession?
    ) {
        self.typeDescriptor = String(describing: workflow.self)
        self.renderKey = renderKey
        self.sessionID = Self.makeSessionID()
        self.parent = parent
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
    func workflowDidChange<WorkflowType: Workflow>(
        from oldWorkflow: WorkflowType,
        to newWorkflow: WorkflowType,
        state: WorkflowType.State,
        session: WorkflowSession
    ) {}

    func onActionSent<Action: WorkflowAction>(
        action: Action,
        session: WorkflowSession
    ) {}

    func workflowWillApplyAction<WorkflowType, Action: WorkflowAction>(
        _ action: Action,
        workflow: WorkflowType,
        state: Action.WorkflowType.State,
        session: WorkflowSession
    ) -> ((WorkflowType.State) -> Void)? where Action.WorkflowType == WorkflowType { nil }
}

// MARK: Chained Observer

struct ChainedWorkflowObserver: WorkflowObserver {
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

    func workflowWillRender<WorkflowType>(_ workflow: WorkflowType, state: WorkflowType.State, session: WorkflowSession) -> ((WorkflowType.Rendering) -> Void)? where WorkflowType: Workflow {
        let callbacks = observers.compactMap {
            $0.workflowWillRender(workflow, state: state, session: session)
        }

        guard !callbacks.isEmpty else { return nil }

        return { rendering in
            for callback in callbacks {
                callback(rendering)
            }
        }
    }

    func workflowDidChange<WorkflowType>(from oldWorkflow: WorkflowType, to newWorkflow: WorkflowType, state: WorkflowType.State, session: WorkflowSession) where WorkflowType: Workflow {
        for observer in observers {
            observer.workflowDidChange(
                from: oldWorkflow,
                to: newWorkflow,
                state: state,
                session: session
            )
        }
    }

    func workflowWillApplyAction<WorkflowType, Action>(_ action: Action, workflow: WorkflowType, state: Action.WorkflowType.State, session: WorkflowSession) -> ((WorkflowType.State) -> Void)? where WorkflowType == Action.WorkflowType, Action: WorkflowAction {
        let callbacks = observers.compactMap { observer in
            observer.workflowWillApplyAction(
                action,
                workflow: workflow,
                state: state,
                session: session
            )
        }

        return { state in
            for callback in callbacks {
                callback(state)
            }
        }
    }

    func onActionSent<Action: WorkflowAction>(
        action: Action,
        session: WorkflowSession
    ) {
        for observer in observers {
            observer.onActionSent(action: action, session: session)
        }
    }
}

extension Array where Element == WorkflowObserver {
    func chained() -> WorkflowObserver? {
        isEmpty ? nil : ChainedWorkflowObserver(observers: self)
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

    public func onActionSent<Action>(
        action: Action,
        session: WorkflowSession
    ) where Action: WorkflowAction {
        switch action {
        case let action as LoggableAction:
            // TODO: maybe there is a way to avoid dynamic casting
            log("got loggable action: \(action.loggingDescription)")
        default:
            log("got default action: \(String(describing: action))")
        }
    }

    public func actionWillBeApplied_completionAPI<Action>(
        action: Action,
        state: Action.WorkflowType.State,
        onPostApply: inout ((Action.WorkflowType.State) -> Void)?,
        session: WorkflowSession
    ) where Action: WorkflowAction {
        print("action applied")
        onPostApply = { state in
            print("got updated state: \(state)")
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
    var renderStartTimes: [UInt64: TimeInterval] = [:]

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

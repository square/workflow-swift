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

@_spi(WorkflowRuntimeConfig) @testable import Workflow

/// Renders to a model that contains a callback, which in turn sends an output event.
struct StateTransitioningWorkflow: Workflow {
    typealias State = Bool

    typealias Output = Never

    struct Rendering {
        var toggle: () -> Void
        var currentValue: Bool
    }

    func makeInitialState() -> Bool {
        false
    }

    func render(state: State, context: RenderContext<StateTransitioningWorkflow>) -> Rendering {
        let sink = context.makeSink(of: Event.self)

        return Rendering(
            toggle: { sink.send(.toggle) },
            currentValue: state
        )
    }

    enum Event: WorkflowAction {
        case toggle

        typealias WorkflowType = StateTransitioningWorkflow

        func apply(toState state: inout Bool, context: ApplyContext<WorkflowType>) -> Never? {
            switch self {
            case .toggle:
                state.toggle()
            }
            return nil
        }
    }
}

// MARK: - HostContext

extension HostContext {
    static func testing(
        observer: WorkflowObserver? = nil,
        debugger: WorkflowDebugger? = nil,
        runtimeConfig: Runtime.Configuration = Runtime.configuration
    ) -> HostContext {
        HostContext(
            observer: observer,
            debugger: debugger,
            runtimeConfig: runtimeConfig,
            onSinkEvent: { perform, _ in perform() }
        )
    }
}

// MARK: - WorkflowDebugger

struct TestDebugger: WorkflowDebugger {
    func didEnterInitialState(
        snapshot: WorkflowHierarchyDebugSnapshot
    ) {}

    func didUpdate(
        snapshot: WorkflowHierarchyDebugSnapshot,
        updateInfo: WorkflowUpdateDebugInfo
    ) {}
}

// MARK: - ApplyContext

extension ApplyContext {
    var wrappedConcreteContext: ConcreteApplyContext<WorkflowType>? {
        wrappedContext as? ConcreteApplyContext<WorkflowType>
    }

    var concreteStorage: WorkflowType? {
        wrappedConcreteContext?.storage
    }
}

// MARK: - Runtime.Config

extension Runtime {
    static func resetConfig() {
        Runtime._bootstrapConfiguration = .init()
    }
}

// MARK: - WorkflowObserver

final class TestObserver: WorkflowObserver {
    var onSessionBegan: ((WorkflowSession) -> Void)?
    var onSessionEnded: ((WorkflowSession) -> Void)?
    /// (Workflow, State, Session) -> Void
    var onDidMakeInitialState: ((Any, Any, WorkflowSession) -> Void)?
    /// (Workflow, State, Session) -> ((Rendering) -> Void)?
    var onWillRender: ((Any, Any, WorkflowSession) -> ((Any) -> Void)?)?
    /// (Workflow [old], Workflow [new], State, Session) -> Void
    var onDidChange: ((Any, Any, Any, WorkflowSession) -> Void)?
    /// (Action, Workflow, Session) -> Void
    var onDidReceiveAction: ((Any, Any, WorkflowSession) -> Void)?
    /// (Action, Workflow, State, Session) -> ((State, Output?) -> Void)?
    var onApplyAction: ((Any, Any, Any, WorkflowSession) -> ((Any, Any) -> Void)?)?

    func sessionDidBegin(_ session: WorkflowSession) {
        onSessionBegan?(session)
    }

    func sessionDidEnd(_ session: WorkflowSession) {
        onSessionEnded?(session)
    }

    func workflowDidMakeInitialState<WorkflowType>(
        _ workflow: WorkflowType,
        initialState: WorkflowType.State,
        session: WorkflowSession
    ) where WorkflowType: Workflow {
        onDidMakeInitialState?(workflow, initialState, session)
    }

    func workflowWillRender<WorkflowType>(_ workflow: WorkflowType, state: WorkflowType.State, session: WorkflowSession) -> ((WorkflowType.Rendering) -> Void)? where WorkflowType: Workflow {
        onWillRender?(workflow, state, session)
    }

    func workflowDidChange<WorkflowType>(from oldWorkflow: WorkflowType, to newWorkflow: WorkflowType, state: WorkflowType.State, session: WorkflowSession) where WorkflowType: Workflow {
        onDidChange?(oldWorkflow, newWorkflow, state, session)
    }

    func workflowDidReceiveAction<Action: WorkflowAction>(_ action: Action, workflow: Action.WorkflowType, session: WorkflowSession) {
        onDidReceiveAction?(action, workflow, session)
    }

    func workflowWillApplyAction<Action: WorkflowAction>(_ action: Action, workflow: Action.WorkflowType, state: Action.WorkflowType.State, session: WorkflowSession) -> ((Action.WorkflowType.State, Action.WorkflowType.Output?) -> Void)? {
        onApplyAction?(action, workflow, state, session)
    }
}

// MARK: - Generic

func drainMainQueueBySpinningRunLoop(timeoutSeconds: UInt = 1) {
    var done = false
    DispatchQueue.main.async { done = true }

    let deadline = ContinuousClock.now + .seconds(timeoutSeconds)
    while !done, ContinuousClock.now < deadline {
        // Turn one iteration at a time
        RunLoop.main.run(until: .now)
    }
}

func drainMainQueue() async {
    await withCheckedContinuation { done in
        DispatchQueue.main.async { done.resume() }
    }
}

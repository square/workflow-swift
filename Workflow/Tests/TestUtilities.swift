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

@testable import Workflow

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
        debugger: WorkflowDebugger? = nil
    ) -> HostContext {
        HostContext(
            observer: observer,
            debugger: debugger
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

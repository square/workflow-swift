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

        func apply(toState state: inout Bool) -> Never? {
            switch self {
            case .toggle:
                state.toggle()
            }
            return nil
        }
    }
}

// MARK: -

extension HostContext {
    static func testing(
        observer: WorkflowObserver? = nil,
        onTerminalOutput: (() -> Void)? = nil
    ) -> HostContext {
        HostContext(
            observer: observer,
            debugger: nil,
            onTerminalOutput: onTerminalOutput
        )
    }
}

enum ShortCircuitTesting {
    struct ParentWorkflow: Workflow {
        typealias State = Void
        typealias Output = ChildWorkflow.Action

        struct Rendering {
            var sendChildAction: (ChildWorkflow.Action) -> Void
        }

        func render(
            state: State,
            context: RenderContext<ParentWorkflow>
        ) -> Rendering {
            let childOutputHandler = ChildWorkflow()
                .mapOutput { output in
                    ParentAction.propagateChildOutput(output)
                }
                .rendered(in: context)

            return Rendering { childAction in
                childOutputHandler(childAction)
            }
        }

        enum ParentAction: WorkflowAction {
            typealias WorkflowType = ParentWorkflow

            case propagateChildOutput(ChildWorkflow.Output)

            func apply(toState state: inout State) -> Output? {
                switch self {
                case .propagateChildOutput(let output):
                    output
                }
            }
        }
    }

    struct ChildWorkflow: Workflow {
        typealias State = Void
        typealias Output = Action
        typealias Rendering = (Action) -> Void

        func render(
            state: State,
            context: RenderContext<ChildWorkflow>
        ) -> Rendering {
            let sink = context.makeSink(of: Action.self)
            return sink.send(_:)
        }

        enum Action: WorkflowAction, Equatable {
            typealias WorkflowType = ChildWorkflow

            case propagatingEvent(String)
            case ignoredEvent

            func apply(toState state: inout State) -> Output? {
                switch self {
                case .propagatingEvent:
                    self
                case .ignoredEvent:
                    nil
                }
            }
        }
    }
}

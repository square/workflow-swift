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

// MARK: - Experimental Observer Stuff

public protocol RenderContextInterceptor {
    // would this be useful?
}

public protocol WorkflowInterceptor {
    func onSessionStarted(
        _ session: WorkflowSession
    )

    func onMakeInitialState<
        W: Workflow
    >(
        workflow: W,
        proceed: (W) -> W.State,
        session: WorkflowSession
    ) -> W.State

    func onRender<
        W: Workflow
    >(
        workflow: W,
        state: W.State,
        proceed: (W, W.State) -> W.Rendering,
        session: WorkflowSession
    ) -> W.Rendering

    func onActionSent<Action: WorkflowAction>(
        action: Action,
        proceed: (Action) -> Void,
        session: WorkflowSession
    )
}

// no-op interface
public protocol NoOpDefaultWorkflowInterceptor: WorkflowInterceptor {}

public extension NoOpDefaultWorkflowInterceptor {
    func onSessionStarted(_ session: WorkflowSession) {}

    func onMakeInitialState<
        W: Workflow
    >(
        workflow: W,
        proceed: (W) -> W.State,
        session: WorkflowSession
    ) -> W.State {
        proceed(workflow)
    }

    func onRender<
        W: Workflow
    >(
        workflow: W,
        state: W.State,
        proceed: (W, W.State) -> W.Rendering,
        session: WorkflowSession
    ) -> W.Rendering {
        proceed(workflow, state)
    }

    func onActionSent<Action: WorkflowAction>(
        action: Action,
        proceed: (Action) -> Void,
        session: WorkflowSession
    ) {
        proceed(action)
    }
}

struct NoOpWorkflowInterceptorImpl: NoOpDefaultWorkflowInterceptor {
    init() {}
}

public class WorkflowInterceptorImpl: NoOpDefaultWorkflowInterceptor {
    public func onRender<W: Workflow>(
        workflow: W,
        state: W.State,
        proceed: (W, W.State) -> W.Rendering,
        session: WorkflowSession
    ) -> W.Rendering {
        print("[interceptor]: about to render")
        defer { print("[interceptor]: rendered") }

        return proceed(workflow, state)
    }
}

public class WorkflowSession {
    private static var _nextID: UInt64 = 0
    static func makeSessionID() -> UInt64 {
        _nextID += 1
        return _nextID
    }

    public let type: Any.Type

    public let renderKey: String

    public let sessionID: UInt64

    public let parent: WorkflowSession?

    init<WorkflowType: Workflow>(
        workflow: WorkflowType,
        renderKey: String,
        parent: WorkflowSession?
    ) {
        self.type = WorkflowType.self
        self.renderKey = renderKey
        self.sessionID = Self.makeSessionID()
        self.parent = parent
    }
}

struct ChainedWorkflowInterceptor: WorkflowInterceptor {
    private let interceptors: [any WorkflowInterceptor]

    init(interceptors: [WorkflowInterceptor]) {
        self.interceptors = interceptors
    }

    func onSessionStarted(_ session: WorkflowSession) {
        interceptors.forEach {
            $0.onSessionStarted(session)
        }
    }

    func onMakeInitialState<W>(
        workflow: W,
        proceed: (W) -> W.State,
        session: WorkflowSession
    ) -> W.State where W: Workflow {
        let state = withoutActuallyEscaping(proceed) { proceed -> W.State in
            var chainedInvocation = proceed

            for interceptor in interceptors.reversed() {
                let nextInvocation = chainedInvocation

                chainedInvocation = { workflow in
                    interceptor.onMakeInitialState(
                        workflow: workflow,
                        proceed: nextInvocation,
                        session: session
                    )
                }
            }

            return chainedInvocation(workflow)
        }
        return state
    }

    func onRender<W>(
        workflow: W,
        state: W.State,
        proceed: (W, W.State) -> W.Rendering,
        session: WorkflowSession
    ) -> W.Rendering where W: Workflow {
        withoutActuallyEscaping(proceed) { proceed -> W.Rendering in
            var chainedInvocation = proceed

            for interceptor in interceptors.reversed() {
                let nextInvocation = chainedInvocation
                chainedInvocation = { workflow, state in
                    interceptor.onRender(
                        workflow: workflow,
                        state: state,
                        proceed: nextInvocation,
                        session: session
                    )
                }
            }

            return chainedInvocation(workflow, state)
        }
    }

    func onActionSent<Action>(
        action: Action,
        proceed: (Action) -> Void,
        session: WorkflowSession
    ) where Action: WorkflowAction {
        withoutActuallyEscaping(proceed) { proceed in
            var chainedInvocation = proceed

            for interceptor in interceptors.reversed() {
                let nextInvocation = chainedInvocation

                chainedInvocation = { action in
                    interceptor.onActionSent(
                        action: action,
                        proceed: nextInvocation,
                        session: session
                    )
                }
            }

            chainedInvocation(action)
        }
    }
}

extension Array where Element == WorkflowInterceptor {
    func chained() -> ChainedWorkflowInterceptor {
        ChainedWorkflowInterceptor(interceptors: self)
    }
}

protocol LoggableAction {
    var loggingDescription: String { get }
}

public struct RootRenderPassTimer: NoOpDefaultWorkflowInterceptor {
    public init() {}

    public func onRender<W>(workflow: W, state: W.State, proceed: (W, W.State) -> W.Rendering, session: WorkflowSession) -> W.Rendering where W: Workflow {
        if session.parent == nil {
            let tock = CACurrentMediaTime()
            defer {
                let tick = CACurrentMediaTime()
                let renderDuration = tick - tock

                print("[interceptor]: root render duration: \(renderDuration)")
            }

            return proceed(workflow, state)
        } else {
            return proceed(workflow, state)
        }
    }
}

public struct SimpleActionLogger: NoOpDefaultWorkflowInterceptor {
    public init() {}

    let log: (String) -> Void = {
        print("[interceptor]: " + $0)
    }

    public func onActionSent<Action>(
        action: Action,
        proceed: (Action) -> Void,
        session: WorkflowSession
    ) where Action: WorkflowAction {
        switch action {
        case let action as LoggableAction:
            // TODO: maybe there is a way to avoid dynamic casting
            log("got loggable action: \(action.loggingDescription)")
        default:
            log("got default action of type: \(String(describing: action.self))")
        }
        proceed(action)
    }
}

// counts number of nodes created over time (in a single tree)
final class SimpleSessionCounter: NoOpDefaultWorkflowInterceptor {
    var sessionCount = 0

    func onSessionStarted(_ session: WorkflowSession) {
        sessionCount += 1
        print("session count: \(sessionCount)")
    }
}

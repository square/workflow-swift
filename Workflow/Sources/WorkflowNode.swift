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

import QuartzCore

/// Manages a running workflow.
final class WorkflowNode<WorkflowType: Workflow> {
    /// Holds the current state of the workflow
    private var state: WorkflowType.State

    /// Holds the current workflow.
    private var workflow: WorkflowType

    // TODO: add session info of some sort

    var interceptor: WorkflowInterceptor

    var onOutput: ((Output) -> Void)?

    /// Manages the children of this workflow, including diffs during/after render passes.
    private let subtreeManager: SubtreeManager

    public let session: WorkflowSession

    init(
        workflow: WorkflowType,
        key: String = "",
        interceptor: WorkflowInterceptor = NoOpWorkflowInterceptorImpl(),
        parentSession: WorkflowSession? = nil
    ) {
        /// Get the initial state
        self.workflow = workflow
        self.interceptor = interceptor
        self.session = WorkflowSession(
            workflow: workflow,
            renderKey: key,
            parent: parentSession
        )
        self.subtreeManager = SubtreeManager(
            session: session,
            interceptor: interceptor
        )

        interceptor.onSessionStarted(session)

        self.state = interceptor.onMakeInitialState(
            workflow: workflow,
            proceed: { $0.makeInitialState() },
            session: session
        )

        WorkflowLogger.logWorkflowStarted(ref: self)

        subtreeManager.onUpdate = { [weak self] output in
            self?.handle(subtreeOutput: output)
        }
    }

    deinit {
        // TODO: session did end?
        WorkflowLogger.logWorkflowFinished(ref: self)
    }

    /// Handles an event produced by the subtree manager
    private func handle(subtreeOutput: SubtreeManager.Output) {
        let output: Output

        switch subtreeOutput {
        case .update(let event, let source):
            /// Apply the update to the current state
            let outputEvent = event.apply(toState: &state)

            /// Finally, we tell the outside world that our state has changed (including an output event if it exists).
            output = Output(
                outputEvent: outputEvent,
                debugInfo: WorkflowUpdateDebugInfo(
                    workflowType: "\(WorkflowType.self)",
                    kind: .didUpdate(source: source)
                )
            )

        case .childDidUpdate(let debugInfo):
            output = Output(
                outputEvent: nil,
                debugInfo: WorkflowUpdateDebugInfo(
                    workflowType: "\(WorkflowType.self)",
                    kind: .childDidUpdate(debugInfo)
                )
            )
        }

        onOutput?(output)
    }

    /// Internal method that forwards the render call through the underlying `subtreeManager`,
    /// and eventually to the client-specified `Workflow` instance.
    /// - Parameter isRootNode: whether or not this is the root node of the tree. Note, this
    /// is currently only used as a hint for the logging infrastructure, and is up to callers to correctly specify.
    /// - Returns: A `Rendering` of appropriate type
    func render(isRootNode: Bool = false) -> WorkflowType.Rendering {
        WorkflowLogger.logWorkflowStartedRendering(ref: self, isRootNode: isRootNode)

        // TODO: full-tree render pass info can be recorded based on root node info

        defer {
            WorkflowLogger.logWorkflowFinishedRendering(ref: self, isRootNode: isRootNode)
        }

        return interceptor.onRender(
            workflow: workflow,
            state: state,
            proceed: { workflow, state in
                subtreeManager.render { context in
                    workflow
                        .render(
                            state: state,
                            context: context
                        )
                }
            },
            session: session
        )
    }

    func enableEvents() {
        subtreeManager.enableEvents()
    }

    /// Updates the workflow.
    func update(workflow: WorkflowType) {
        workflow.workflowDidChange(from: self.workflow, state: &state)
        self.workflow = workflow
    }

    func makeDebugSnapshot() -> WorkflowHierarchyDebugSnapshot {
        return WorkflowHierarchyDebugSnapshot(
            workflowType: "\(WorkflowType.self)",
            stateDescription: "\(state)",
            children: subtreeManager.makeDebugSnapshot()
        )
    }
}

extension WorkflowNode {
    struct Output {
        var outputEvent: WorkflowType.Output?
        var debugInfo: WorkflowUpdateDebugInfo
    }
}

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
        proceed: (Action) -> Void
    )
}

// no-op interface
public protocol NoOpWorkflowInterceptor: WorkflowInterceptor {}

public extension NoOpWorkflowInterceptor {
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
        proceed: (Action) -> Void
    ) {
        proceed(action)
    }
}

struct NoOpWorkflowInterceptorImpl: NoOpWorkflowInterceptor {
    init() {}
}

public class WorkflowInterceptorImpl: NoOpWorkflowInterceptor {
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

/**/
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

struct ChainedWorkflowInterceptor: WorkflowInterceptor {
    private let interceptors: [WorkflowInterceptor]

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
        let result: W.State = withoutActuallyEscaping(proceed) { proceed in
            let chainedProceed = interceptors.reduce(proceed) { proceedAccum, interceptor in
                { workflow in
                    interceptor.onMakeInitialState(
                        workflow: workflow,
                        proceed: proceedAccum,
                        session: session
                    )
                }
            }

            return chainedProceed(workflow)
        }

        return result
    }

    func onRender<W>(
        workflow: W,
        state: W.State,
        proceed: (W, W.State) -> W.Rendering,
        session: WorkflowSession
    ) -> W.Rendering where W: Workflow {
        let rez: W.Rendering = withoutActuallyEscaping(proceed) { proceed in
            let chainedProceed = interceptors.reduce(proceed) { partialResult, interceptor in
                { workflow, state in
                    interceptor.onRender(
                        workflow: workflow,
                        state: state,
                        proceed: partialResult,
                        session: session
                    )
                }
            }

            let rendering = chainedProceed(workflow, state)
            return rendering
        }

        return rez
    }

    func onActionSent<Action>(
        action: Action,
        proceed: (Action) -> Void
    ) where Action: WorkflowAction {
        withoutActuallyEscaping(proceed) { proceed in
            let chainedProceed = interceptors.reduce(proceed) { proceedAccum, interceptor in
                { action in
                    interceptor.onActionSent(
                        action: action,
                        proceed: proceedAccum
                    )
                }
            }

            chainedProceed(action)
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

struct RootRenderPassTimer: NoOpWorkflowInterceptor {
    func onRender<W>(workflow: W, state: W.State, proceed: (W, W.State) -> W.Rendering, session: WorkflowSession) -> W.Rendering where W: Workflow {
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

struct SimpleActionLogger: NoOpWorkflowInterceptor {
    let log: (String) -> Void = {
        print("[interceptor]: " + $0)
    }

    func onActionSent<Action>(
        action: Action,
        proceed: (Action) -> Void
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
final class SimpleSessionCounter: NoOpWorkflowInterceptor {
    var sessionCount = 0

    func onSessionStarted(_ session: WorkflowSession) {
        sessionCount += 1
        print("session count: \(sessionCount)")
    }
}

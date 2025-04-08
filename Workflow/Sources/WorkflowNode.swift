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

extension WorkflowNode {
    struct RenderingSnapshot {
        var lastRendering: WorkflowType.Rendering?
    }
}

import Observation

/// Manages a running workflow.
final class WorkflowNode<WorkflowType: Workflow> {
    /// The current `State` of the node's `Workflow`.
    private var state: WorkflowType.State

    private var isTrackingRenderChanges = false
    private var isTrackingDidUpdateChanges = false
    private var cachedRendering = RenderingSnapshot()

    /// Holds the current `Workflow` managed by this node.
    private var workflow: WorkflowType

    /// Reference to the context object for the entity hosting this node.
    let hostContext: HostContext

    /// Manages the children of this workflow, including diffs during/after render passes.
    private let subtreeManager: SubtreeManager

    /// 'Session' metadata associated with this node
    let session: WorkflowSession

    /// Callback to invoke when a child `Output` is produced.
    var onOutput: ((Output) -> Void)?

    /// An optional `WorkflowObserver` instance
    var observer: WorkflowObserver? {
        hostContext.observer
    }

    init(
        workflow: WorkflowType,
        key: String = "",
        hostContext: HostContext,
        parentSession: WorkflowSession? = nil
    ) {
        /// Get the initial state
        self.workflow = workflow
        self.hostContext = hostContext
        self.session = WorkflowSession(
            workflow: workflow,
            renderKey: key,
            parent: parentSession
        )
        self.subtreeManager = SubtreeManager(
            session: session,
            hostContext: hostContext
        )

        hostContext.observer?.sessionDidBegin(session)

        if #available(iOS 17.0, *) {
            self.state = withObservationTracking {
                workflow.makeInitialState()
            } onChange: { [weak hostContext, session] in
                print("JQ: [makeInitialState] WOT onChange: invalidating nodes for session: \(session.sessionID)")
                hostContext?.invalidateNodesForSession(session)
            }
        } else {
            self.state = workflow.makeInitialState()
        }

        observer?.workflowDidMakeInitialState(
            workflow,
            initialState: state,
            session: session
        )

        WorkflowLogger.logWorkflowStarted(ref: self)

        subtreeManager.onUpdate = { [weak self] output in
            self?.handle(subtreeOutput: output)
        }
    }

    deinit {
        observer?.sessionDidEnd(session)
        WorkflowLogger.logWorkflowFinished(ref: self)
    }

    /// Handles an event produced by the subtree manager
    private func handle(subtreeOutput: SubtreeManager.Output) {
        let output: Output

        switch subtreeOutput {
        case .update(let action, let source):
            /// 'Opens' the existential `any WorkflowAction<WorkflowType>` value
            /// allowing the underlying conformance to be applied to the Workflow's State
            let outputEvent = openAndApply(
                action,
                isExternal: source == .external
            )

            /// Finally, we tell the outside world that our state has changed (including an output event if it exists).
            output = Output(
                outputEvent: outputEvent,
                debugInfo: hostContext.ifDebuggerEnabled {
                    WorkflowUpdateDebugInfo(
                        workflowType: "\(WorkflowType.self)",
                        kind: .didUpdate(source: source.toDebugInfoSource())
                    )
                }
            )

        case .childDidUpdate(let debugInfo):
            output = Output(
                outputEvent: nil,
                debugInfo: hostContext.ifDebuggerEnabled {
                    WorkflowUpdateDebugInfo(
                        workflowType: "\(WorkflowType.self)",
                        kind: .childDidUpdate(debugInfo.unwrappedOrErrorDefault)
                    )
                }
            )
        }

        onOutput?(output)
    }

    /// Internal method that forwards the render call through the underlying `subtreeManager`,
    /// and eventually to the client-specified `Workflow` instance.
    /// - Parameter isRootNode: whether or not this is the root node of the tree. Note, this
    /// is currently only used as a hint for the logging infrastructure, and is up to callers to correctly specify.
    /// - Returns: A `Rendering` of appropriate type
    func render() -> WorkflowType.Rendering {
        WorkflowLogger.logWorkflowStartedRendering(ref: self)

        let renderObserverCompletion = observer?.workflowWillRender(
            workflow,
            state: state,
            session: session
        )

        let rendering: WorkflowType.Rendering

        defer {
            renderObserverCompletion?(rendering)

            WorkflowLogger.logWorkflowFinishedRendering(ref: self)
        }

        if
//            false &&
            hostContext.isNodeValid(session.sessionID),
            let cachedRendering = cachedRendering.lastRendering
        {
            // if node isn't invalidated, and we have a cached
            // rendering, use it
            print("JQ: [cache hit] using cached rendering of \(type(of:cachedRendering)) for \(session.sessionID)")
            rendering = cachedRendering
            for eventPipe in subtreeManager.eventPipes {
                eventPipe.prepareForReuse()
            }
        } else {
            // otherwise, produce a new rendering for this node
            if #available(iOS 17.0, *) {

                rendering = subtreeManager.render { context in
                    print("JQ: [cache miss] subtree producing rendering for \(session.sessionID)")
                    if isTrackingRenderChanges {
                        return workflow.render(state: state, context: context)
                    } else {
                        defer { isTrackingRenderChanges = true }
                        return withObservationTracking {
                            return workflow.render(state: state, context: context)
                        } onChange: { [weak self] in
                            guard let self else { return }
                            print("JQ: [render] WOT onChange: invalidating nodes for session: \(session.sessionID)")
                            isTrackingRenderChanges = false
                            hostContext.invalidateNodesForSession(session)
                        }
                    }
                }
            } else {
                rendering = subtreeManager.render { context in
                    print("JQ: [cache miss] subtree producing rendering for \(session.sessionID)")
                    return workflow.render(state: state, context: context)
                }
            }

            // otherwise, produce a new rendering for this node
//            rendering = subtreeManager.render { context in
//                print("JQ: [cache miss] subtree producing rendering for \(session.sessionID)")
//                return workflow.render(state: state, context: context)
//            }

            cachedRendering.lastRendering = rendering
        }

        return rendering
    }

    func enableEvents() {
        subtreeManager.enableEvents()
    }

    /// Updates the workflow.
    func update(workflow: WorkflowType) {
        let oldWorkflow = self.workflow

        print("JQ: updating wf: \(type(of: workflow)) session: \(session.sessionID)")

        if #available(iOS 17.0, *) {
            if isTrackingDidUpdateChanges {
//                var copy = state
                workflow.workflowDidChange(from: oldWorkflow, state: &state)
//                state[keyPath: \.self] = copy
            } else {
                defer { isTrackingDidUpdateChanges = true }
                withObservationTracking {
                    workflow.workflowDidChange(from: oldWorkflow, state: &state)
//                    var obs = ObserverWrapper(val: state)
//                    defer { state = obs.val }
//                    var copy = state[keyPath: \.self]
//                    var hack = unsafeBitCast(obs, to: WorkflowType.State.self)
//                    state = obs.val
//                    withUnsafeMutablePointer(to: &obs) { ptr in
//                        workflow.workflowDidChange(from: oldWorkflow, state: &ptr.pointee.val)
//                    }
//                    state = copy
                } onChange: { [weak self] in
                    guard let self else { return }
                    print("JQ: [WFDidChange] WOT onChange: invalidating nodes for session: \(session.sessionID)")
                    self.isTrackingDidUpdateChanges = true
                    hostContext.invalidateNodesForSession(session)
                }
            }
        } else {
            workflow.workflowDidChange(from: oldWorkflow, state: &state)
        }

//        workflow.workflowDidChange(from: oldWorkflow, state: &state)

        self.workflow = workflow

        observer?.workflowDidChange(
            from: oldWorkflow,
            to: workflow,
            state: state,
            session: session
        )
    }

    func makeDebugSnapshot() -> WorkflowHierarchyDebugSnapshot {
        WorkflowHierarchyDebugSnapshot(
            workflowType: "\(WorkflowType.self)",
            stateDescription: "\(state)",
            children: subtreeManager.makeDebugSnapshot()
        )
    }
}

extension WorkflowNode {
    struct Output {
        var outputEvent: WorkflowType.Output?
        var debugInfo: WorkflowUpdateDebugInfo?
    }
}

@dynamicMemberLookup
struct ObserverWrapper<T> {
    var val: T {
        willSet {
            print("will set: newVal:")
//            dump(newValue)
//            print("old value:")
//            dump(val)
        }
        didSet {
            print("did set")
        }
    }

    subscript<V>(dynamicMember keyPath: WritableKeyPath<T, V>) -> V {
        get {
            self.val[keyPath: keyPath]
        }
        set {
            self.val[keyPath: keyPath] = newValue
        }
    }
}

extension WorkflowNode {
    /// Applies an appropriate `WorkflowAction` to advance the underlying Workflow `State`
    /// - Parameters:
    ///   - action: The `WorkflowAction` to apply
    ///   - isExternal: Whether the handled action came from the 'outside world' vs being bubbled up from a child node
    /// - Returns: An optional `Output` produced by the action application
    private func openAndApply<A: WorkflowAction>(
        _ action: A,
        isExternal: Bool
    ) -> WorkflowType.Output? where A.WorkflowType == WorkflowType {
        let output: WorkflowType.Output?

        // handle specific observation call if this is the first node
        // processing this 'action cascade'
        if isExternal {
            observer?.workflowDidReceiveAction(
                action,
                workflow: workflow,
                session: session
            )

            // invalidate path to root
            hostContext.invalidateNodes(from: self)
//            hostContext.invalidateNodes(from: session)
        }

        let observerCompletion = observer?.workflowWillApplyAction(
            action,
            workflow: workflow,
            state: state,
            session: session
        )
        defer { observerCompletion?(state, output) }

        /// Apply the action to the current state
        output = action.apply(toState: &state)

        return output
    }
}

// MARK: - Utility

extension WorkflowNode {
    var isRootNode: Bool {
        session.parent == nil
    }
}

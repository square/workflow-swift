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

/// Manages a running workflow.
final class WorkflowNode<WorkflowType: Workflow> {
    /// The current `State` of the node's `Workflow`.
    private var state: WorkflowType.State

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

        self.state = workflow.makeInitialState()

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

        rendering = subtreeManager.render { context in
            workflow
                .render(
                    state: state,
                    context: context
                )
        }

        return rendering
    }

    func enableEvents() {
        subtreeManager.enableEvents()
    }

    /// Updates the workflow.
    func update(workflow: WorkflowType) {
        let oldWorkflow = self.workflow

        workflow.workflowDidChange(from: oldWorkflow, state: &state)
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
        }

        let observerCompletion = observer?.workflowWillApplyAction(
            action,
            workflow: workflow,
            state: state,
            session: session
        )
        defer { observerCompletion?(state, output) }

        /// Apply the action to the current state
        do {
            // FIXME: can we avoid instantiating a class here somehow?
            let context = ConcreteApplyContext(storage: workflow)
            defer { context.invalidate() }

            let wrappedContext = ApplyContext.make(implementation: context)
            output = action.apply(toState: &state, context: wrappedContext)
        }

        return output
    }
}

// MARK: - Utility

extension WorkflowNode {
    var isRootNode: Bool {
        session.parent == nil
    }
}

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

import CloudKit
import QuartzCore

/// Manages a running workflow.
final class WorkflowNode<WorkflowType: Workflow> {
    /// Holds the current state of the workflow
    private var state: WorkflowType.State

    /// Holds the current workflow.
    private var workflow: WorkflowType

    // TODO: add session info of some sort

    var observer: WorkflowObserver?

    var onOutput: ((Output) -> Void)?

    /// Manages the children of this workflow, including diffs during/after render passes.
    private let subtreeManager: SubtreeManager

    public let session: WorkflowSession

    init(
        workflow: WorkflowType,
        key: String = "",
        parentSession: WorkflowSession? = nil,
        observer: WorkflowObserver? = nil
    ) {
        /// Get the initial state
        self.workflow = workflow
        self.observer = observer
        self.session = WorkflowSession(
            workflow: workflow,
            renderKey: key,
            parent: parentSession
        )
        self.subtreeManager = SubtreeManager(
            session: session,
            observer: observer
        )

        self.observer?.workflowSessionDidBegin(
            workflow: workflow,
            session: session
        )

        self.state = workflow.makeInitialState()

        // TODO: add session info and/or ability to identify root node
        self.observer?.didMakeInitialState(
            workflow: workflow,
            initialState: state,
            session: session
        )

        WorkflowLogger.logWorkflowStarted(ref: self)

        subtreeManager.onUpdate = { [weak self] output in
            self?.handle(subtreeOutput: output)
        }
    }

    deinit {
        observer?.workflowSessionDidEnd(
            workflow: workflow,
            session: session
        )
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
        // TODO: full-tree render pass info can be recorded based on root node info
        WorkflowLogger.logWorkflowStartedRendering(ref: self, isRootNode: isRootNode)

        // callback API
        observer?.willRender(
            workflow: workflow,
            state: state,
            session: session
        )

        // completion block API
        let renderObserverCompletion = observer?.willRender_completionAPI(
            workflow: workflow,
            state: state,
            session: session
        )

        let rendering: WorkflowType.Rendering

        defer {
            // callback API
            observer?.didRender(
                workflow: workflow,
                state: state,
                rendering: rendering,
                session: session
            )

            // completion block API
            renderObserverCompletion?(rendering)

            WorkflowLogger.logWorkflowFinishedRendering(ref: self, isRootNode: isRootNode)
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
        let newWorkflow = workflow

        workflow.workflowDidChange(from: self.workflow, state: &state)
        self.workflow = workflow

        observer?.workflowDidUpdate(
            oldWorkflow: oldWorkflow,
            newWorkflow: newWorkflow,
            session: session
        )
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

// public protocol WorkflowInterceptor {
//    func render<WorkflowType: Workflow>(
//    ) -> WorkflowType.Rendering
// }

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

/* */

// public protocol WorkflowSession {
//
//    var renderKey: String { get }
//
//    var sessionID: UInt64 { get }
//
//    var parent: WorkflowSession? { get }
// }

public protocol WorkflowObserver {
    func workflowSessionDidBegin<WorkflowType: Workflow>(
        workflow: WorkflowType,
        session: WorkflowSession
    )

    func workflowSessionDidEnd<WorkflowType: Workflow>(
        workflow: WorkflowType,
        session: WorkflowSession
    )

    func didMakeInitialState<WorkflowType: Workflow>(
        workflow: WorkflowType,
        initialState: WorkflowType.State,
        session: WorkflowSession
    )

    func willRender_completionAPI<WorkflowType: Workflow>(
        workflow: WorkflowType,
        state: WorkflowType.State,
        session: WorkflowSession
    ) -> ((WorkflowType.Rendering) -> Void)?

    func willRender<WorkflowType: Workflow>(
        workflow: WorkflowType,
        state: WorkflowType.State,
        session: WorkflowSession
    )

    func didRender<WorkflowType: Workflow>(
        workflow: WorkflowType,
        state: WorkflowType.State,
        rendering: WorkflowType.Rendering,
        session: WorkflowSession
    )

    func workflowDidUpdate<WorkflowType: Workflow>(
        oldWorkflow: WorkflowType,
        newWorkflow: WorkflowType,
        session: WorkflowSession
    )

    func onActionSent<Action: WorkflowAction>(
        action: Action,
        session: WorkflowSession
    )
}

public extension Optional where Wrapped == WorkflowObserver {
    static var test: Self { WorkflowObserverImpl() }
}

final class WorkflowObserverImpl: WorkflowObserver {
    func workflowSessionDidBegin<WorkflowType: Workflow>(
        workflow: WorkflowType,
        session: WorkflowSession
    ) {
        print("session started")
    }

    func workflowSessionDidEnd<WorkflowType: Workflow>(
        workflow: WorkflowType,
        session: WorkflowSession
    ) {
        print("session ended")
    }

    func didMakeInitialState<WorkflowType: Workflow>(
        workflow: WorkflowType,
        initialState: WorkflowType.State,
        session: WorkflowSession
    ) {
        print("did make initial state: \(type(of: initialState))")
    }

    func willRender<WorkflowType: Workflow>(
        workflow: WorkflowType,
        state: WorkflowType.State,
        session: WorkflowSession
    ) {
        print("will render: \(type(of: workflow))")
    }

    func didRender<WorkflowType: Workflow>(
        workflow: WorkflowType,
        state: WorkflowType.State,
        rendering: WorkflowType.Rendering,
        session: WorkflowSession
    ) {
        print("did render: \(type(of: rendering))")
    }

    func workflowDidUpdate<WorkflowType: Workflow>(
        oldWorkflow: WorkflowType,
        newWorkflow: WorkflowType,
        session: WorkflowSession
    ) {
        print("workflow did update")
    }

    func onActionSent<Action: WorkflowAction>(
        action: Action,
        session: WorkflowSession
    ) {
        print("action sent: \(action)")
    }
}

public extension WorkflowObserver {
    func workflowSessionDidBegin<WorkflowType: Workflow>(
        workflow: WorkflowType,
        session: WorkflowSession
    ) {}

    func workflowSessionDidEnd<WorkflowType: Workflow>(
        workflow: WorkflowType,
        session: WorkflowSession
    ) {}

    func didMakeInitialState<WorkflowType: Workflow>(
        workflow: WorkflowType,
        initialState: WorkflowType.State,
        session: WorkflowSession
    ) {}

    func willRender_completionAPI<WorkflowType: Workflow>(
        workflow: WorkflowType,
        state: WorkflowType.State,
        session: WorkflowSession
    ) -> ((WorkflowType.Rendering) -> Void)? {
        nil
    }

    func willRender<WorkflowType: Workflow>(
        workflow: WorkflowType,
        state: WorkflowType.State,
        session: WorkflowSession
    ) {}

    func didRender<WorkflowType: Workflow>(
        workflow: WorkflowType,
        state: WorkflowType.State,
        rendering: WorkflowType.Rendering,
        session: WorkflowSession
    ) {}

    func workflowDidUpdate<WorkflowType: Workflow>(
        oldWorkflow: WorkflowType,
        newWorkflow: WorkflowType,
        session: WorkflowSession
    ) {}

    func onActionSent<Action: WorkflowAction>(
        action: Action,
        session: WorkflowSession
    ) {}
}

struct ChainedWorkflowObserver: WorkflowObserver {
    private let observers: [WorkflowObserver]

    init(observers: [WorkflowObserver]) {
        self.observers = observers
    }

    func workflowSessionDidBegin<WorkflowType: Workflow>(
        workflow: WorkflowType,
        session: WorkflowSession
    ) {
        observers.forEach { $0.workflowSessionDidBegin(workflow: workflow, session: session) }
    }

    func workflowSessionDidEnd<WorkflowType: Workflow>(
        workflow: WorkflowType,
        session: WorkflowSession
    ) {
        observers.forEach {
            $0.workflowSessionDidEnd(workflow: workflow, session: session)
        }
    }

    func didMakeInitialState<WorkflowType: Workflow>(
        workflow: WorkflowType,
        initialState: WorkflowType.State,
        session: WorkflowSession
    ) {
        observers.forEach { $0.didMakeInitialState(
            workflow: workflow,
            initialState: initialState,
            session: session
        ) }
    }

    func willRender_completionAPI<WorkflowType>(
        workflow: WorkflowType,
        state: WorkflowType.State,
        session: WorkflowSession
    ) -> ((WorkflowType.Rendering) -> Void)? where WorkflowType: Workflow {
        let callbacks = observers.compactMap {
            $0.willRender_completionAPI(
                workflow: workflow,
                state: state,
                session: session
            )
        }

        guard !callbacks.isEmpty else { return nil }

        return { rendering in
            callbacks.forEach { callback in
                callback(rendering)
            }
        }
    }

    func willRender<WorkflowType>(
        workflow: WorkflowType,
        state: WorkflowType.State,
        session: WorkflowSession
    ) where WorkflowType: Workflow {
        observers.forEach {
            $0.willRender(
                workflow: workflow,
                state: state,
                session: session
            )
        }
    }

    func didRender<WorkflowType>(
        workflow: WorkflowType,
        state: WorkflowType.State,
        rendering: WorkflowType.Rendering,
        session: WorkflowSession
    ) where WorkflowType: Workflow {
        observers.forEach {
            $0.didRender(
                workflow: workflow,
                state: state,
                rendering: rendering,
                session: session
            )
        }
    }

    func workflowDidUpdate<WorkflowType: Workflow>(
        oldWorkflow: WorkflowType,
        newWorkflow: WorkflowType,
        session: WorkflowSession
    ) {
        observers.forEach { $0.workflowDidUpdate(
            oldWorkflow: oldWorkflow,
            newWorkflow: newWorkflow,
            session: session
        ) }
    }

    func onActionSent<Action: WorkflowAction>(
        action: Action,
        session: WorkflowSession
    ) {
        observers.forEach { $0.onActionSent(action: action, session: session) }
    }
}

extension Array where Element == WorkflowObserver {
    func chained() -> ChainedWorkflowObserver {
        ChainedWorkflowObserver(observers: self)
    }
}

protocol LoggableAction {
    var loggingDescription: String { get }
}

struct SimpleActionLogger: WorkflowObserver {
    let log: (String) -> Void = {
        print($0)
    }

    func onActionSent<Action: WorkflowAction>(action: Action) {
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
final class SimpleSessionCounter: WorkflowObserver {
    var sessionCount = 0

    func workflowSessionDidBegin<WorkflowType>(
        workflow: WorkflowType,
        session: WorkflowSession
    ) where WorkflowType: Workflow {
        sessionCount += 1
        print("session count: \(sessionCount)")
    }
}

final class SimpleRenderTimingObserver: WorkflowObserver {
    var renderStartTimes: [UInt64: TimeInterval] = [:]

    init() {}

    func willRender_completionAPI<WorkflowType>(
        workflow: WorkflowType,
        state: WorkflowType.State,
        session: WorkflowSession
    ) -> ((WorkflowType.Rendering) -> Void)? where WorkflowType: Workflow {
        let start = CACurrentMediaTime()

        let onRenderComplete = { (rendering: WorkflowType.Rendering) in
            let end = CACurrentMediaTime()
            let renderTime = end - start
            let timingMillis = renderTime / 1000
            print("render of node: \(session.sessionID) completed in \(timingMillis) ms")
        }

        return onRenderComplete
    }

    /*
     func willRender<WorkflowType>(
         workflow: WorkflowType,
         state: WorkflowType.State,
         session: WorkflowSession
     ) where WorkflowType : Workflow {
         let start = CACurrentMediaTime()
         renderStartTimes[session.sessionID] = start
     }

     func didRender<WorkflowType>(
         workflow: WorkflowType,
         state: WorkflowType.State,
         rendering: WorkflowType.Rendering,
         session: WorkflowSession
     ) where WorkflowType : Workflow {
         let end = CACurrentMediaTime()
         let start = renderStartTimes.removeValue(forKey: session.sessionID)!

         let renderTime = end - start
         let timingMillis = renderTime / 1000
         print("render of node: \(session.sessionID) completed in \(timingMillis) ms")
     }
      */
}

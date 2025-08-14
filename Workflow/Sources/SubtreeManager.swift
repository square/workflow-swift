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

import Dispatch

extension WorkflowNode {
    /// Manages the subtree of a workflow. Specifically, this type encapsulates the logic required to update and manage
    /// the lifecycle of nested workflows across multiple render passes.
    final class SubtreeManager {
        var onUpdate: ((Output) -> Void)?

        /// Sinks from the outside world (i.e. UI)
        private(set) var eventPipes: [EventPipe] = []

        /// Reusable sinks from the previous render pass
        private var previousSinks: [ObjectIdentifier: AnyReusableSink] = [:]

        /// The current array of children
        private(set) var childWorkflows: [ChildKey: AnyChildWorkflow] = [:]

        /// The current array of side-effects
        private(set) var sideEffectLifetimes: [AnyHashable: SideEffectLifetime] = [:]

        private let session: WorkflowSession

        /// Reference to the context object for the entity hosting the corresponding node.
        private let hostContext: HostContext

        private var observer: WorkflowObserver? {
            hostContext.observer
        }

        init(
            session: WorkflowSession,
            hostContext: HostContext
        ) {
            self.session = session
            self.hostContext = hostContext
        }

        /// Performs an update pass using the given closure.
        func render<Rendering>(
            _ actions: (RenderContext<WorkflowType>) -> Rendering
        ) -> Rendering {
            /// Invalidate the previous action handlers.
            for eventPipe in eventPipes {
                eventPipe.invalidate()
            }

            /// Create a workflow context containing the existing children
            let context = Context(
                previousSinks: previousSinks,
                originalChildWorkflows: childWorkflows,
                originalSideEffectLifetimes: sideEffectLifetimes,
                hostContext: hostContext,
                session: session
            )

            let wrapped = RenderContext.make(implementation: context)

            /// Pass the context into the closure to allow a render to take place
            let rendering = actions(wrapped)

            wrapped.invalidate()

            /// After the render is complete, assign children using *only the children that were used during the render
            /// pass.* This means that any pre-existing children that were *not* used during the render pass are removed
            /// as a result of this call to `render`.
            childWorkflows = context.usedChildWorkflows
            sideEffectLifetimes = context.usedSideEffectLifetimes

            /// Capture the reusable sinks from this render pass.
            previousSinks = context.sinkStore.usedSinks

            /// Capture all the pipes to be enabled after render completes.
            eventPipes = context.eventPipes
            for (_, sink) in context.sinkStore.usedSinks {
                eventPipes.append(sink.eventPipe)
            }

            /// Set all event pipes to `pending`.
            for eventPipe in eventPipes {
                eventPipe.setPending()
            }

            /// Return the rendered result
            return rendering
        }

        /// Enable the eventPipes for the previous rendering. The eventPipes are not valid until this has
        /// be called. It is an error to call this twice without generating a new rendering.
        func enableEvents() {
            /// Enable all action pipes.
            for eventPipe in eventPipes {
                eventPipe.enable { [weak self] output in
                    self?.handle(output: output)
                }
            }

            /// Enable all child workflows.
            for child in childWorkflows {
                child.value.enableEvents()
            }
        }

        func makeDebugSnapshot() -> [WorkflowHierarchyDebugSnapshot.Child] {
            childWorkflows
                .sorted(by: { lhs, rhs -> Bool in
                    lhs.key.key < rhs.key.key
                })
                .map {
                    WorkflowHierarchyDebugSnapshot.Child(
                        key: $0.key.key,
                        snapshot: $0.value.makeDebugSnapshot()
                    )
                }
        }

        private func handle(output: Output) {
            onUpdate?(output)
        }
    }
}

/// Carries information about the provenance of an event handled by the runtime.
enum EventSource: Equatable {
    /// An event received from an external source.
    case external

    /// An event that comes from a descendent in the subtree.
    /// Will contain associated debug info iff the `debugger` property of the `WorkflowHost`
    /// is set.
    case subtree(WorkflowUpdateDebugInfo?)

    /// Compatibility method to convert to the public representation of this data
    func toDebugInfoSource() -> WorkflowUpdateDebugInfo.Source {
        switch self {
        case .external: .external
        case .subtree(let maybeInfo): .subtree(maybeInfo.unwrappedOrErrorDefault)
        }
    }
}

extension WorkflowNode.SubtreeManager {
    /// The possible output types that a SubtreeManager can produce.
    enum Output {
        /// Indicates that an event produced a `WorkflowAction` to apply to the node.
        ///
        /// - Parameters:
        ///   - action: The `WorkflowAction` to be applied to the node.
        ///   - source: The event source that triggered this update. This is primarily used to differentiate between 'external' events and events that originate from the subtree itself.
        ///   - subtreeInvalidated: A boolean indicating whether at least one descendant workflow has been invalidated during this update.
        case update(
            any WorkflowAction<WorkflowType>,
            source: EventSource,
            subtreeInvalidated: Bool
        )

        /// Indicates that a child workflow within the subtree handled an event and was updated. This informs the parent node about the change and propagates the update 'up' the tree.
        ///
        /// - Parameters:
        ///   - debugInfo: Optional debug information about the workflow update.
        ///   - subtreeInvalidated: A boolean indicating whether at least one descendant workflow has been invalidated during this update.
        case childDidUpdate(
            WorkflowUpdateDebugInfo?,
            subtreeInvalidated: Bool
        )
    }
}

// MARK: - Render Context

extension WorkflowNode.SubtreeManager {
    /// The workflow context implementation used by the subtree manager.
    fileprivate final class Context: RenderContextType {
        private(set) var eventPipes: [EventPipe]

        private(set) var sinkStore: SinkStore

        private let originalChildWorkflows: [ChildKey: AnyChildWorkflow]
        private(set) var usedChildWorkflows: [ChildKey: AnyChildWorkflow]

        private let originalSideEffectLifetimes: [AnyHashable: SideEffectLifetime]
        private(set) var usedSideEffectLifetimes: [AnyHashable: SideEffectLifetime]

        private let hostContext: HostContext
        private let session: WorkflowSession

        private var observer: WorkflowObserver? {
            hostContext.observer
        }

        init(
            previousSinks: [ObjectIdentifier: AnyReusableSink],
            originalChildWorkflows: [ChildKey: AnyChildWorkflow],
            originalSideEffectLifetimes: [AnyHashable: SideEffectLifetime],
            hostContext: HostContext,
            session: WorkflowSession
        ) {
            self.eventPipes = []
            self.sinkStore = SinkStore(previousSinks: previousSinks)

            self.originalChildWorkflows = originalChildWorkflows
            self.usedChildWorkflows = [:]

            self.originalSideEffectLifetimes = originalSideEffectLifetimes
            self.usedSideEffectLifetimes = [:]

            self.hostContext = hostContext
            self.session = session
        }

        func render<Child: Workflow, Action: WorkflowAction>(
            workflow: Child,
            key: String,
            outputMap: @escaping (Child.Output) -> Action
        ) -> Child.Rendering
            where WorkflowType == Action.WorkflowType
        {
            /// A unique key used to identify this child workflow
            let childKey = ChildKey(childType: Child.self, key: key)

            let child: ChildWorkflow<Child>
            let eventPipe = EventPipe()
            eventPipes.append(eventPipe)

            /// See if we can reuse an existing child node for the given key.
            if let existing = originalChildWorkflows[childKey] {
                /// Cast the untyped child into a specific typed child. Because our children are keyed by their workflow
                /// type, this should never fail.
                guard let existing = existing as? ChildWorkflow<Child> else {
                    fatalError("ChildKey class type does not match the underlying workflow type.")
                }

                /// Update the existing child
                existing.update(
                    workflow: workflow,
                    outputMap: { outputMap($0) },
                    eventPipe: eventPipe
                )
                child = existing
            } else {
                /// We could not find an existing child matching the given child key, so we will generate a new child.
                /// This spins up a new workflow node, etc to host the newly created child.
                child = ChildWorkflow<Child>(
                    workflow: workflow,
                    outputMap: { outputMap($0) },
                    eventPipe: eventPipe,
                    key: key,
                    hostContext: hostContext,
                    parentSession: session
                )
            }

            /// Store the resolved child in `used`. This allows us to a) hold on to any used children after this render
            /// pass, and b) ensure that we never allow the use of a given workflow type with identical keys.
            let keyWasUnused = usedChildWorkflows.updateValue(child, forKey: childKey) == nil

            /// If the key was already in `used`, then a workflow of the same type was rendered multiple times
            /// during this render pass with the same key. This is not allowed.
            guard keyWasUnused else {
                fatalError("Child workflows of the same type must be given unique keys. Duplicate workflows of type \(Child.self) were encountered with the key \"\(key)\" in \(WorkflowType.self)")
            }

            return child.render()
        }

        func makeSink<Action: WorkflowAction>(
            of actionType: Action.Type
        ) -> Sink<Action> where WorkflowType == Action.WorkflowType {
            let reusableSink = sinkStore.findOrCreate(actionType: Action.self)

            let sink = Sink<Action> { [weak reusableSink] action in
                WorkflowLogger.logSinkEvent(ref: SignpostRef(), action: action)

                // use a weak reference as we'd like control over the lifetime
                reusableSink?.handle(action: action)
            }

            return sink
        }

        func runSideEffect(
            key: AnyHashable,
            action: (Lifetime) -> Void
        ) {
            if let existingSideEffect = originalSideEffectLifetimes[key] {
                usedSideEffectLifetimes[key] = existingSideEffect
            } else {
                let sideEffectLifetime = SideEffectLifetime()
                action(sideEffectLifetime.lifetime)
                usedSideEffectLifetimes[key] = sideEffectLifetime
            }
        }
    }
}

// MARK: - Reusable Sink

extension WorkflowNode.SubtreeManager {
    fileprivate struct SinkStore {
        private var previousSinks: [ObjectIdentifier: AnyReusableSink]
        private(set) var usedSinks: [ObjectIdentifier: AnyReusableSink]

        init(previousSinks: [ObjectIdentifier: AnyReusableSink]) {
            self.previousSinks = previousSinks
            self.usedSinks = [:]
        }

        mutating func findOrCreate<Action: WorkflowAction>(actionType: Action.Type) -> ReusableSink<Action> {
            let key = ObjectIdentifier(actionType)

            let reusableSink: ReusableSink<Action>

            if let previousSink = previousSinks.removeValue(forKey: key) as? ReusableSink<Action> {
                // Reuse a previous sink, creating a new event pipe to send the action through.
                previousSink.eventPipe = EventPipe()
                reusableSink = previousSink
            } else if let usedSink = usedSinks[key] as? ReusableSink<Action> {
                // Multiple sinks using the same backing sink.
                reusableSink = usedSink
            } else {
                // Create a new reusable sink.
                reusableSink = ReusableSink<Action>()
            }

            usedSinks[key] = reusableSink

            return reusableSink
        }
    }

    /// Type-erased base class for reusable sinks.
    fileprivate class AnyReusableSink {
        var eventPipe: EventPipe

        init() {
            self.eventPipe = EventPipe()
        }
    }

    fileprivate final class ReusableSink<Action: WorkflowAction>: AnyReusableSink where Action.WorkflowType == WorkflowType {
        func handle(action: Action) {
            let output = Output.update(
                action,
                source: .external,
                subtreeInvalidated: false // initial state
            )

            if case .pending = eventPipe.validationState {
                // Workflow is currently processing an `event`.
                // Scheduling it to be processed after.
                DispatchQueue.workflowExecution.async { [weak self] in
                    self?.eventPipe.handle(event: output)
                }
                return
            }
            eventPipe.handle(event: output)
        }
    }
}

// MARK: - EventPipe

extension WorkflowNode.SubtreeManager {
    final class EventPipe {
        var validationState: ValidationState
        enum ValidationState {
            case preparing
            case pending
            case valid(handler: (Output) -> Void)
            case invalid
        }

        /// Utility to detect reentrancy in `handle()`
        private var isHandlingEvent: Bool = false

        init() {
            self.validationState = .preparing
        }

        func handle(event: Output) {
            dispatchPrecondition(condition: .onQueue(DispatchQueue.workflowExecution))

            let isReentrantCall = isHandlingEvent
            isHandlingEvent = true
            defer { isHandlingEvent = isReentrantCall }

            switch validationState {
            case .preparing:
                fatalError("[\(WorkflowType.self)] Sink sent an action inside `render`. Sinks are not valid until `render` has completed.")

            case .pending:
                fatalError("[\(WorkflowType.self)] Action sent to pipe while in the `pending` state.")

            case .valid(let handler):
                handler(event)

            case .invalid:
                #if DEBUG
                // Reentrancy seems to often be due to UIKit behaviors over
                // which we have little control (e.g. synchronous resignation
                // of first responder after a new Rendering is assigned). Emit
                // some debug info in these cases.
                if isReentrantCall {
                    print("[\(WorkflowType.self)]: ℹ️ Sink sent another action after it was invalidated but before its original action handling was resolved. This new action will be ignored. If this is unexpected, set a Swift error breakpoint on `\(InvalidSinkSentAction.self)` to debug.")
                }

                do {
                    throw InvalidSinkSentAction()
                } catch {}
                #endif

                // If we're invalid and this is the first time `handle()` has
                // been called, then it's likely we've somehow been inadvertently
                // retained from the 'outside world'. Fail more loudly in this case.
                assert(isReentrantCall, """
                    [\(WorkflowType.self)]: Sink sent an action after it was invalidated. This action will be ignored.
                """)
            }
        }

        func setPending() {
            guard case .preparing = validationState else {
                fatalError("Attempted to `setPending` an EventPipe that was not in the preparing state.")
            }
            validationState = .pending
        }

        func enable(with handler: @escaping (Output) -> Void) {
            guard case .pending = validationState else {
                fatalError("EventPipe can only be enabled from the `pending` state")
            }
            validationState = .valid(handler: handler)
        }

        func invalidate() {
            validationState = .invalid
        }
    }
}

// MARK: - ChildKey

extension WorkflowNode.SubtreeManager {
    struct ChildKey: Hashable {
        var childTypeID: ObjectIdentifier
        var key: String

        init(
            childType: (some Workflow).Type,
            key: String
        ) {
            self.childTypeID = ObjectIdentifier(childType)
            self.key = key
        }
    }
}

// MARK: - Child Workflows

extension WorkflowNode.SubtreeManager {
    /// Abstract base class for running children in the subtree.
    class AnyChildWorkflow {
        fileprivate var eventPipe: EventPipe

        fileprivate init(eventPipe: EventPipe) {
            self.eventPipe = eventPipe
        }

        func enableEvents() {
            fatalError()
        }

        func makeDebugSnapshot() -> WorkflowHierarchyDebugSnapshot {
            fatalError()
        }
    }

    fileprivate final class ChildWorkflow<W: Workflow>: AnyChildWorkflow {
        private let node: WorkflowNode<W>
        private var outputMap: (W.Output) -> any WorkflowAction<WorkflowType>

        init(
            workflow: W,
            outputMap: @escaping (W.Output) -> any WorkflowAction<WorkflowType>,
            eventPipe: EventPipe,
            key: String,
            hostContext: HostContext,
            parentSession: WorkflowSession?
        ) {
            self.outputMap = outputMap
            self.node = WorkflowNode<W>(
                workflow: workflow,
                key: key,
                hostContext: hostContext,
                parentSession: parentSession
            )

            super.init(eventPipe: eventPipe)

            node.onOutput = { [weak self] output in
                self?.handle(workflowOutput: output)
            }
        }

        override func enableEvents() {
            node.enableEvents()
        }

        func render() -> W.Rendering {
            node.render()
        }

        func update(
            workflow: W,
            outputMap: @escaping (W.Output) -> any WorkflowAction<WorkflowType>,
            eventPipe: EventPipe
        ) {
            self.outputMap = outputMap
            self.eventPipe = eventPipe
            node.update(workflow: workflow)
        }

        private func handle(workflowOutput: WorkflowNode<W>.Output) {
            let output = if let outputEvent = workflowOutput.outputEvent {
                Output.update(
                    outputMap(outputEvent),
                    source: .subtree(workflowOutput.debugInfo),
                    subtreeInvalidated: workflowOutput.subtreeInvalidated
                )
            } else {
                Output.childDidUpdate(
                    workflowOutput.debugInfo,
                    subtreeInvalidated: workflowOutput.subtreeInvalidated
                )
            }

            eventPipe.handle(event: output)
        }

        override func makeDebugSnapshot() -> WorkflowHierarchyDebugSnapshot {
            node.makeDebugSnapshot()
        }
    }
}

// MARK: - Side Effects

extension WorkflowNode.SubtreeManager {
    class SideEffectLifetime {
        fileprivate let lifetime: Lifetime

        fileprivate init() {
            self.lifetime = Lifetime()
        }

        deinit {
            // Explicitly end the lifetime in case someone retained it from outside
            lifetime.end()
        }
    }
}

// MARK: - Debugging Utilities

#if DEBUG
private struct InvalidSinkSentAction: Error {}
#endif

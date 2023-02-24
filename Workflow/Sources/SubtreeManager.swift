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
    internal final class SubtreeManager {
        internal var onUpdate: ((Output) -> Void)?

        /// Sinks from the outside world (i.e. UI)
        internal private(set) var eventPipes: [EventPipe] = []

        /// Reusable sinks from the previous render pass
        private var previousSinks: [ObjectIdentifier: AnyReusableSink] = [:]

        /// The current array of children
        internal private(set) var childWorkflows: [ChildKey: AnyChildWorkflow] = [:]

        /// The current array of side-effects
        internal private(set) var sideEffectLifetimes: [AnyHashable: SideEffectLifetime] = [:]

        private let session: WorkflowSession

        private let observer: WorkflowObserver?

        init(
            session: WorkflowSession,
            observer: WorkflowObserver? = nil
        ) {
            self.session = session
            self.observer = observer
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
                session: session,
                observer: observer
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

            /// Captured the reusable sinks from this render pass.
            previousSinks = context.sinkStore.usedSinks

            /// Capture all the pipes to be enabled after render completes.
            eventPipes = context.eventPipes
            eventPipes.append(contentsOf: context.sinkStore.eventPipes)

            /// Set all event pipes to `pending`.
            eventPipes.forEach { $0.setPending() }

            /// Return the rendered result
            return rendering
        }

        /// Enable the eventPipes for the previous rendering. The eventPipes are not valid until this has
        /// be called. If is an error to call this twice without generating a new rendering.
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
            return childWorkflows
                .sorted(by: { (lhs, rhs) -> Bool in
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

extension WorkflowNode.SubtreeManager {
    enum Output {
        case update(any WorkflowAction<WorkflowType>, source: WorkflowUpdateDebugInfo.Source)
        case childDidUpdate(WorkflowUpdateDebugInfo)
    }
}

// MARK: - Render Context

extension WorkflowNode.SubtreeManager {
    /// The workflow context implementation used by the subtree manager.
    fileprivate final class Context: RenderContextType {
        internal private(set) var eventPipes: [EventPipe]

        internal private(set) var sinkStore: SinkStore

        private let originalChildWorkflows: [ChildKey: AnyChildWorkflow]
        internal private(set) var usedChildWorkflows: [ChildKey: AnyChildWorkflow]

        private let originalSideEffectLifetimes: [AnyHashable: SideEffectLifetime]
        internal private(set) var usedSideEffectLifetimes: [AnyHashable: SideEffectLifetime]

        private let session: WorkflowSession
        private let observer: WorkflowObserver?

        internal init(
            previousSinks: [ObjectIdentifier: AnyReusableSink],
            originalChildWorkflows: [ChildKey: AnyChildWorkflow],
            originalSideEffectLifetimes: [AnyHashable: SideEffectLifetime],
            session: WorkflowSession,
            observer: WorkflowObserver?
        ) {
            self.eventPipes = []

            self.sinkStore = SinkStore(previousSinks: previousSinks)

            self.originalChildWorkflows = originalChildWorkflows
            self.usedChildWorkflows = [:]

            self.originalSideEffectLifetimes = originalSideEffectLifetimes
            self.usedSideEffectLifetimes = [:]

            self.session = session
            self.observer = observer
        }

        func render<Child, Action>(
            workflow: Child,
            key: String,
            outputMap: @escaping (Child.Output) -> Action
        ) -> Child.Rendering
            where Child: Workflow,
            Action: WorkflowAction,
            WorkflowType == Action.WorkflowType {
            /// A unique key used to identify this child workflow
            let childKey = ChildKey(childType: Child.self, key: key)

            /// If the key already exists in `used`, then a workflow of the same type has been rendered multiple times
            /// during this render pass with the same key. This is not allowed.
            guard usedChildWorkflows[childKey] == nil else {
                fatalError("Child workflows of the same type must be given unique keys. Duplicate workflows of type \(Child.self) were encountered with the key \"\(key)\" in \(WorkflowType.self)")
            }

            let child: ChildWorkflow<Child>
            let eventPipe = EventPipe()
            eventPipes.append(eventPipe)

            /// See if we can
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
                    parentSession: session,
                    observer: observer
                )
            }

            /// Store the resolved child in `used`. This allows us to a) hold on to any used children after this render
            /// pass, and b) ensure that we never allow the use of a given workflow type with identical keys.
            usedChildWorkflows[childKey] = child
            return child.render()
        }

        func makeSink<Action>(of actionType: Action.Type) -> Sink<Action> where Action: WorkflowAction, WorkflowType == Action.WorkflowType {
            let reusableSink = sinkStore.findOrCreate(actionType: Action.self)

            let sink = Sink<Action> { [weak reusableSink] action in
                WorkflowLogger.logSinkEvent(ref: SignpostRef(), action: action)

                // use a weak reference as we'd like control over the lifetime
                reusableSink?.handle(action: action)
            }

            return sink
        }

        func runSideEffect(key: AnyHashable, action: (Lifetime) -> Void) {
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
        var eventPipes: [EventPipe] {
            return usedSinks.values.map { reusableSink -> EventPipe in
                reusableSink.eventPipe
            }
        }

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
            let output = Output.update(action, source: .external)

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
    internal final class EventPipe {
        var validationState: ValidationState
        enum ValidationState {
            case preparing
            case pending
            case valid(handler: (Output) -> Void)
            case invalid
        }

        init() {
            self.validationState = .preparing
        }

        func handle(event: Output) {
            dispatchPrecondition(condition: .onQueue(DispatchQueue.workflowExecution))

            switch validationState {
            case .preparing:
                fatalError("[\(WorkflowType.self)] Sink sent an action inside `render`. Sinks are not valid until `render` has completed.")

            case .pending:
                fatalError("[\(WorkflowType.self)] Action sent to pipe while in the `pending` state.")

            case .valid(let handler):
                handler(event)

            case .invalid:
                fatalError("[\(WorkflowType.self)] Sink sent an action after it was invalidated. Sinks can only be used for a single valid `Rendering`.")
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
        var childType: Any.Type
        var key: String

        init<T>(childType: T.Type, key: String) {
            self.childType = childType
            self.key = key
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(ObjectIdentifier(childType))
            hasher.combine(key)
        }

        static func == (lhs: ChildKey, rhs: ChildKey) -> Bool {
            return lhs.childType == rhs.childType
                && lhs.key == rhs.key
        }
    }
}

// MARK: - Child Workflows

extension WorkflowNode.SubtreeManager {
    /// Abstract base class for running children in the subtree.
    internal class AnyChildWorkflow {
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
            parentSession: WorkflowSession?,
            observer: WorkflowObserver?
        ) {
            self.outputMap = outputMap
            self.node = WorkflowNode<W>(
                workflow: workflow,
                key: key,
                parentSession: parentSession,
                observer: observer
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
            return node.render(isRootNode: false)
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
            let output: Output

            if let outputEvent = workflowOutput.outputEvent {
                output = Output.update(
                    outputMap(outputEvent),
                    source: .subtree(workflowOutput.debugInfo)
                )
            } else {
                output = Output.childDidUpdate(workflowOutput.debugInfo)
            }

            eventPipe.handle(event: output)
        }

        override func makeDebugSnapshot() -> WorkflowHierarchyDebugSnapshot {
            return node.makeDebugSnapshot()
        }
    }
}

// MARK: - Side Effects

extension WorkflowNode.SubtreeManager {
    internal class SideEffectLifetime {
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

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
import ReactiveSwift

/// Defines a type that receives debug information about a running workflow hierarchy.
public protocol WorkflowDebugger {
    /// Called once when the workflow hierarchy initializes.
    ///
    /// - Parameter snapshot: Debug information about the workflow hierarchy.
    func didEnterInitialState(snapshot: WorkflowHierarchyDebugSnapshot)

    /// Called when an update occurs anywhere within the workflow hierarchy.
    ///
    /// - Parameter snapshot: Debug information about the workflow hierarchy *after* the update.
    /// - Parameter updateInfo: Information about the update.
    func didUpdate(snapshot: WorkflowHierarchyDebugSnapshot, updateInfo: WorkflowUpdateDebugInfo)
}

/// Manages an active workflow hierarchy.
public final class WorkflowHost<WorkflowType: Workflow> {
    private let (outputEvent, outputEventObserver) = Signal<WorkflowType.Output, Never>.pipe()

    // @testable
    let rootNode: WorkflowNode<WorkflowType>

    private let mutableRendering: MutableProperty<WorkflowType.Rendering>

    /// Represents the `Rendering` produced by the root workflow in the hierarchy. New `Rendering` values are produced
    /// as state transitions occur within the hierarchy.
    public let rendering: Property<WorkflowType.Rendering>

    /// Context object to pass down to descendant nodes in the tree.
    let context: HostContext

    private var debugger: WorkflowDebugger? {
        context.debugger
    }

    let eventHandler: SinkEventHandler

    /// Initializes a new host with the given workflow at the root.
    ///
    /// - Parameter workflow: The root workflow in the hierarchy
    /// - Parameter observers: An optional array of `WorkflowObservers` that will allow runtime introspection for this `WorkflowHost`
    /// - Parameter debugger: An optional debugger. If provided, the host will notify the debugger of updates
    ///                       to the workflow hierarchy as state transitions occur.
    public init(
        workflow: WorkflowType,
        observers: [WorkflowObserver] = [],
        debugger: WorkflowDebugger? = nil
    ) {
        self.eventHandler = SinkEventHandler()
        assert(
            eventHandler.state == .initializing,
            "EventHandler must begin in the `.initializing` state"
        )
        defer { eventHandler.state = .ready }

        let observer = WorkflowObservation
            .sharedObserversInterceptor
            .workflowObservers(for: observers)
            .chained()

        self.context = HostContext(
            observer: observer,
            debugger: debugger,
            runtimeConfig: Runtime.configuration,
            onSinkEvent: eventHandler.makeOnSinkEventCallback()
        )

        self.rootNode = WorkflowNode(
            workflow: workflow,
            hostContext: context,
            parentSession: nil
        )

        self.mutableRendering = MutableProperty(rootNode.render())
        self.rendering = Property(mutableRendering)
        rootNode.enableEvents()

        debugger?.didEnterInitialState(snapshot: rootNode.makeDebugSnapshot())

        rootNode.onOutput = { [weak self] output in
            self?.handle(output: output)
        }
    }

    /// Update the input for the workflow. Will cause a render pass.
    public func update(workflow: WorkflowType) {
        rootNode.update(workflow: workflow)

        // Treat the update as an "output" from the workflow originating from an external event to force a render pass.
        let output = WorkflowNode<WorkflowType>.Output(
            outputEvent: nil,
            debugInfo: context.ifDebuggerEnabled {
                WorkflowUpdateDebugInfo(
                    workflowType: "\(WorkflowType.self)",
                    kind: .didUpdate(source: .external)
                )
            },
            subtreeInvalidated: true // treat as an invalidation
        )
        handle(output: output)
    }

    private func handle(output: WorkflowNode<WorkflowType>.Output) {
        let shouldRender = !shouldSkipRenderForOutput(output)
        if shouldRender {
            mutableRendering.value = rootNode.render()
        }

        // Always emit an output, regardless of whether a render occurs
        if let outputEvent = output.outputEvent {
            outputEventObserver.send(value: outputEvent)
        }

        debugger?.didUpdate(
            snapshot: rootNode.makeDebugSnapshot(),
            updateInfo: output.debugInfo.unwrappedOrErrorDefault
        )

        // If we rendered, the event pipes must be re-enabled
        if shouldRender {
            rootNode.enableEvents()
        }
    }

    /// A signal containing output events emitted by the root workflow in the hierarchy.
    public var output: Signal<WorkflowType.Output, Never> {
        outputEvent
    }
}

// MARK: - Conditional Rendering Utilities

extension WorkflowHost {
    private func shouldSkipRenderForOutput(
        _ output: WorkflowNode<WorkflowType>.Output
    ) -> Bool {
        // We can skip the render pass if:
        //  1. The runtime config supports this behavior.
        //  2. No subtree invalidation occurred during action processing.
        context.runtimeConfig.renderOnlyIfStateChanged
            && !output.subtreeInvalidated
    }
}

// MARK: - HostContext

/// A context object to expose certain root-level information to each node
/// in the Workflow tree.
struct HostContext {
    let observer: WorkflowObserver?
    let debugger: WorkflowDebugger?
    let runtimeConfig: Runtime.Configuration

    /// Event handler to be plumbed through the runtime down to the Sinks
    let onSinkEvent: OnSinkEvent

    init(
        observer: WorkflowObserver?,
        debugger: WorkflowDebugger?,
        runtimeConfig: Runtime.Configuration,
        onSinkEvent: @escaping OnSinkEvent
    ) {
        self.observer = observer
        self.debugger = debugger
        self.runtimeConfig = runtimeConfig
        self.onSinkEvent = onSinkEvent
    }
}

extension HostContext {
    func ifDebuggerEnabled<T>(
        _ perform: () -> T
    ) -> T? {
        debugger != nil ? perform() : nil
    }
}

// MARK: - EventHandler

/// Callback signature for the internal `ReusableSink` types to invoke when
/// they receive an event from the 'outside world'.
/// - Parameter perform: The event handler to invoke if the event can be processed immediately.
/// - Parameter enqueue: The event handler to invoke in the future if the event cannot currently be processed.
typealias OnSinkEvent = (
    _ perform: () -> Void,
    _ enqueue: @escaping () -> Void
) -> Void

/// Handles events from 'Sinks' such that runtime-level event handling state is appropriately
/// managed, and attempts to perform reentrant action handling can be detected and dealt with.
final class SinkEventHandler {
    enum State {
        /// The handler (and related components) are being
        /// initialized, and are not yet ready to process events.
        /// Attempts to do so in this state will fail with a fatal error.
        case initializing

        /// An event is currently being processed.
        case processingEvent

        /// Ready to handle an event.
        case ready
    }

    fileprivate(set) var state: State = .initializing

    /// Synchronously performs or enqueues the specified event handlers based on the current
    /// event handler state.
    /// - Parameters:
    ///   - perform: The event handling action to perform immediately if possible.
    ///   - enqueue: The event handling action to enqueue if the event handler is already processing an event.
    func performOrEnqueueEvent(
        perform: () -> Void,
        enqueue: @escaping () -> Void
    ) {
        switch state {
        case .initializing:
            fatalError("Tried to handle event before finishing initialization.")

        case .processingEvent:
            DispatchQueue.workflowExecution.async(execute: enqueue)

        case .ready:
            state = .processingEvent
            defer { state = .ready }
            perform()
        }
    }

    /// Creates the callback that should be invoked by Sinks to handle their event appropriately
    /// given the `EventHandler`'s current state.
    /// - Returns: The callback that should be invoked.
    func makeOnSinkEventCallback() -> OnSinkEvent {
        // TODO: do we need the weak ref?
        let onSinkEvent: OnSinkEvent = { [weak self] perform, enqueue in
            guard let self else {
                return // TODO: what's the appropriate handling?
            }

            performOrEnqueueEvent(perform: perform, enqueue: enqueue)
        }

        return onSinkEvent
    }
}

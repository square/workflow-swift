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

import Combine
import Dispatch

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
@MainActor
public final class WorkflowHost<WorkflowType: Workflow> {
    private let outputSubject = PassthroughSubject<WorkflowType.Output, Never>()

    // @testable
    let rootNode: WorkflowNode<WorkflowType>

    private let renderingSubject: CurrentValueSubject<WorkflowType.Rendering, Never>

    private let renderingMulticaster = AsyncMulticaster<WorkflowType.Rendering>()
    private let outputMulticaster = AsyncMulticaster<WorkflowType.Output>()

    /// Erased hooks into the multicasters, installed lazily by the `renderings`
    /// and `outputs` accessors (whose extensions know the element types are
    /// `Sendable`). `nil` until the corresponding stream is first requested.
    private var yieldRendering: ((WorkflowType.Rendering) -> Void)?
    private var yieldOutput: ((WorkflowType.Output) -> Void)?

    /// The current `Rendering` produced by the root workflow in the hierarchy. A new `Rendering` value is produced
    /// as state transitions occur within the hierarchy.
    public var rendering: WorkflowType.Rendering {
        renderingSubject.value
    }

    /// A publisher of the `Rendering` values produced by the root workflow in the hierarchy. Emits the current
    /// `Rendering` when subscribed to, followed by a new value after each subsequent render pass. Use
    /// `dropFirst()` to observe only changes.
    public var renderingPublisher: AnyPublisher<WorkflowType.Rendering, Never> {
        renderingSubject.eraseToAnyPublisher()
    }

    /// Context object to pass down to descendant nodes in the tree.
    let context: HostContext

    private var debugger: WorkflowDebugger? {
        context.debugger
    }

    let sinkEventHandler: SinkEventHandler

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
        self.sinkEventHandler = SinkEventHandler()
        defer { sinkEventHandler.state = .ready }

        let observer = WorkflowObservation
            .sharedObserversInterceptor
            .workflowObservers(for: observers)
            .chained()

        let config = Runtime.configuration
        let sinkEventCallback = config.useSinkEventHandler ? sinkEventHandler.makeOnSinkEventCallback() : nil

        self.context = HostContext(
            observer: observer,
            debugger: debugger,
            runtimeConfig: config,
            onSinkEvent: sinkEventCallback
        )

        self.rootNode = WorkflowNode(
            workflow: workflow,
            hostContext: context,
            parentSession: nil
        )

        self.renderingSubject = CurrentValueSubject(rootNode.render())
        rootNode.enableEvents()

        debugger?.didEnterInitialState(snapshot: rootNode.makeDebugSnapshot())

        rootNode.onOutput = { [weak self] output in
            self?.handle(output: output)
        }
    }

    deinit {
        // Not an `isolated deinit`: the Swift 6.3.2 optimizer crashes when
        // compiling isolated deinits of generic classes in release builds.
        // The host is main-actor-isolated, so the last reference is expected
        // to be released on the main actor.
        MainActor.assumeIsolated {
            renderingSubject.send(completion: .finished)
            outputSubject.send(completion: .finished)
        }
    }

    /// Update the input for the workflow. Will cause a render pass.
    public func update(workflow: WorkflowType) {
        if context.runtimeConfig.useSinkEventHandler {
            sinkEventHandler.withEventHandlingSuspended {
                updateRootNode(workflow: workflow)
            }
        } else {
            updateRootNode(workflow: workflow)
        }
    }

    private func updateRootNode(workflow: WorkflowType) {
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
            let rendering = rootNode.render()
            renderingSubject.send(rendering)
            yieldRendering?(rendering)
        }

        // Always emit an output, regardless of whether a render occurs
        if let outputEvent = output.outputEvent {
            outputSubject.send(outputEvent)
            yieldOutput?(outputEvent)
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

    /// A publisher of the output events emitted by the root workflow in the hierarchy.
    public var outputPublisher: AnyPublisher<WorkflowType.Output, Never> {
        outputSubject.eraseToAnyPublisher()
    }
}

extension WorkflowHost where WorkflowType.Rendering: Sendable {
    /// An asynchronous sequence of the `Rendering` values produced by the root
    /// workflow in the hierarchy. Yields the most recent `Rendering` when
    /// iteration begins, followed by a new value after each subsequent render
    /// pass. A slow consumer only ever observes the latest rendering; stale
    /// intermediate values are dropped.
    ///
    /// Each access returns an independent stream. Obtain a fresh stream per
    /// consumer; a single stream must not be iterated more than once.
    public var renderings: AsyncStream<WorkflowType.Rendering> {
        if yieldRendering == nil {
            yieldRendering = { [renderingMulticaster] in
                renderingMulticaster.yield($0)
            }
        }
        return renderingMulticaster.makeStream(
            bufferingPolicy: .bufferingNewest(1),
            initial: renderingSubject.value
        )
    }
}

extension WorkflowHost where WorkflowType.Output: Sendable {
    /// An asynchronous sequence of the output events emitted by the root
    /// workflow in the hierarchy. Every output emitted after the stream is
    /// created is delivered, in order — the stream buffers without dropping.
    ///
    /// Each access returns an independent stream. Obtain a fresh stream per
    /// consumer; a single stream must not be iterated more than once.
    public var outputs: AsyncStream<WorkflowType.Output> {
        if yieldOutput == nil {
            yieldOutput = { [outputMulticaster] in
                outputMulticaster.yield($0)
            }
        }
        return outputMulticaster.makeStream(bufferingPolicy: .unbounded)
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

    /// Event handler to be plumbed through the runtime down to the (reusable) Sinks.
    let onSinkEvent: OnSinkEvent?

    init(
        observer: WorkflowObserver?,
        debugger: WorkflowDebugger?,
        runtimeConfig: Runtime.Configuration,
        onSinkEvent: OnSinkEvent?
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

// MARK: - SinkEventHandler

/// Callback signature for the internal `ReusableSink` types to invoke when
/// they receive an event from the 'outside world'.
/// - Parameter immediatePerform: The event handler to invoke if the event can be processed immediately.
/// - Parameter deferredPerform: The event handler to invoke in the future if the event cannot currently be processed.
typealias OnSinkEvent = (
    _ immediatePerform: () -> Void,
    _ deferredPerform: @escaping () -> Void
) -> Void

/// Handles events from 'Sinks' such that runtime-level event handling state is appropriately
/// managed, and attempts to perform reentrant action handling can be detected and dealt with.
@MainActor
final class SinkEventHandler {
    enum State {
        /// Ready to handle an event.
        case ready

        /// The event handler is busy. Usually this indicates another event is being
        /// processed, but it may also be set when some other condition prevents
        /// event handling (e.g. a `WorkflowHost` was told to update its root node).
        case busy
    }

    fileprivate(set) var state: State

    init(state: State = .busy) {
        self.state = state
    }

    /// Synchronously performs or enqueues the specified event handlers based on the current
    /// event handler state.
    /// - Parameters:
    ///   - immediate: The event handling action to perform immediately if possible.
    ///   - deferred: The event handling action to enqueue if the event handler is already processing an event.
    func performOrEnqueueEvent(
        immediate: () -> Void,
        deferred: @escaping () -> Void
    ) {
        switch state {
        case .ready:
            withEventHandlingSuspended(immediate)

        case .busy:
            // Delivery stays on the main actor; relative ordering with other
            // main-queue work is best-effort per Task scheduling semantics.
            // Non-Sendable captures are legal because creation context and
            // Task isolation are both MainActor (no region crossing).
            Task { @MainActor in
                deferred()
            }
        }
    }

    /// Invokes the given closure with event handling explicitly set to the `busy` state, so
    /// any incoming events produced while executing the closure's body will be enqueued.
    /// - Parameter body: The closure to invoke.
    func withEventHandlingSuspended(_ body: () -> Void) {
        switch state {
        case .ready:
            state = .busy
            defer { state = .ready }
            body()

        case .busy:
            body()
        }
    }

    /// Creates the callback that should be invoked by Sinks to handle their event appropriately
    /// given the `SinkEventHandler`'s current state.
    /// - Returns: The callback that should be invoked.
    func makeOnSinkEventCallback() -> OnSinkEvent {
        // We may not actually need the weak ref, but it's more defensive to keep it.
        let onSinkEvent: OnSinkEvent = { [weak self] immediate, deferred in
            guard let self else {
                // We just drop the events here. Should we signal this somehow?
                // Maybe as a debug-only thing? Or is it just noise?
                return
            }

            performOrEnqueueEvent(
                immediate: immediate,
                deferred: deferred
            )
        }

        return onSinkEvent
    }
}

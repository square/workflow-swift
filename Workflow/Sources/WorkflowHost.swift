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

    /// Initializes a new host with the given workflow at the root.
    ///
    /// - Parameter workflow: The root workflow in the hierarchy
    /// - Parameter observers: An optional array of `WorkflowObservers` that will allow runtime introspection for this `WorkflowHost`
    /// - Parameter debugger: An optional debugger. If provided, the host will notify the debugger of updates
    ///                       to the workflow hierarchy as state transitions occur.
    public init(
        workflow: WorkflowType,
        observers: [WorkflowObserver] = [],
        debugger: WorkflowDebugger? = nil,
        options: HostOptions? = nil
    ) {
        let opts = options ?? defaultHostOptions

        let observer = WorkflowObservation
            .sharedObserversInterceptor
            .workflowObservers(for: observers)
            .chained()

        self.context = HostContext(
            observer: observer,
            debugger: debugger,
            options: .init(canSkipRootRenderIfStateUnchanged: opts.contains(.renderOnlyIfStateChanged))
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
            }
        )
        // Explicitly enable re-rendering in this case as
        // no action propagation occurred so the skip rendering
        // flag could be stale
        context.setNeedsRootRender()
        handle(output: output)
    }

    private func handle(output: WorkflowNode<WorkflowType>.Output) {
        let newRendering = context.renderIfNeeded(rootNode.render)

        if let newRendering {
            mutableRendering.value = newRendering
        } else {
            __debug_onRootRenderSkipped()
        }

        if let outputEvent = output.outputEvent {
            outputEventObserver.send(value: outputEvent)
        }

        debugger?.didUpdate(
            snapshot: rootNode.makeDebugSnapshot(),
            updateInfo: output.debugInfo.unwrappedOrErrorDefault
        )

        // Re-enable event handlers if we rendered
        if newRendering != nil {
            rootNode.enableEvents()
        }
    }

    /// A signal containing output events emitted by the root workflow in the hierarchy.
    public var output: Signal<WorkflowType.Output, Never> {
        outputEvent
    }
}

public struct HostOptions: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let renderOnlyIfStateChanged = HostOptions(rawValue: 1 << 0)
}

public var defaultHostOptions: HostOptions = [.renderOnlyIfStateChanged]

// MARK: - HostContext

/// A context object to expose certain root-level information to each node
/// in the Workflow tree.
final class HostContext {
    let observer: WorkflowObserver?
    let debugger: WorkflowDebugger?
    let options: Options

    private var _maybeNeedsRootRender = true

    var needsRootRender: Bool {
        guard options.canSkipRootRenderIfStateUnchanged else {
            return true
        }

        return _maybeNeedsRootRender
    }

    fileprivate func renderIfNeeded<T>(_ render: () -> T) -> T? {
        defer { _maybeNeedsRootRender = false }

        guard needsRootRender else { return nil }
        return render()
    }

    func setNeedsRootRender() {
        guard options.canSkipRootRenderIfStateUnchanged,
              !_maybeNeedsRootRender
        else { return }

        _maybeNeedsRootRender = true
    }

    // MARK: -

    var canSkipRenders: Bool {
        options.canSkipRootRenderIfStateUnchanged
    }

    init(
        observer: WorkflowObserver?,
        debugger: WorkflowDebugger?,
        options: Options = .default
    ) {
        self.observer = observer
        self.debugger = debugger
        self.options = options
    }
}

extension HostContext {
    func ifDebuggerEnabled<T>(
        _ perform: () -> T
    ) -> T? {
        debugger != nil ? perform() : nil
    }
}

extension HostContext {
    struct Options {
        static let `default` = Options()

        var canSkipRootRenderIfStateUnchanged: Bool = false
    }
}

@inline(never)
func __debug_onRootRenderSkipped() {}

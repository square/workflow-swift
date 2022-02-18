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

import Foundation

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
    private let debugger: WorkflowDebugger?

    private let rootNode: WorkflowNode<WorkflowType>

    /// Represents the `Rendering` produced by the root workflow in the hierarchy. New `Rendering` values are produced
    /// as state transitions occur within the hierarchy.
    public private(set) var rendering: WorkflowType.Rendering

    private var renderingListeners: [UUID: Listener<WorkflowType.Rendering>] = [:]
    private var outputListeners: [UUID: Listener<WorkflowType.Output>] = [:]

    /// Initializes a new host with the given workflow at the root.
    ///
    /// - Parameter workflow: The root workflow in the hierarchy
    /// - Parameter debugger: An optional debugger. If provided, the host will notify the debugger of updates
    ///                       to the workflow hierarchy as state transitions occur.
    public init(workflow: WorkflowType, debugger: WorkflowDebugger? = nil) {
        self.debugger = debugger

        self.rootNode = WorkflowNode(workflow: workflow)

        self.rendering = rootNode.render()
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
            debugInfo: WorkflowUpdateDebugInfo(
                workflowType: "\(WorkflowType.self)",
                kind: .didUpdate(source: .external)
            )
        )
        handle(output: output)
    }

    // Rendering
    public func addRenderingListener(_ closure: @escaping (WorkflowType.Rendering) -> Void) -> UUID {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
        let listener = ClosureListener<WorkflowType.Rendering>(listener: closure)
        renderingListeners[listener.id] = listener
        return listener.id
    }

    public func addRenderingListener(listener: Listener<WorkflowType.Rendering>) {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
        renderingListeners[listener.id] = listener
    }

    public func getRenderingListener(id: UUID) -> Listener<WorkflowType.Rendering>? {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
        return renderingListeners[id]
    }

    public func removeRenderingListener(id: UUID) {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
        renderingListeners.removeValue(forKey: id)
    }

    // Output
    public func addOutputListener(_ closure: @escaping (WorkflowType.Output) -> Void) -> UUID {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
        let listener = ClosureListener<WorkflowType.Output>(listener: closure)
        outputListeners[listener.id] = listener
        return listener.id
    }

    public func addOutputListener(listener: Listener<WorkflowType.Output>) {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
        outputListeners[listener.id] = listener
    }

    public func getOutputListener(id: UUID) -> Listener<WorkflowType.Output>? {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
        return outputListeners[id]
    }

    public func removeOutputListener(id: UUID) {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
        outputListeners.removeValue(forKey: id)
    }

    private func handle(output: WorkflowNode<WorkflowType>.Output) {
        rendering = rootNode.render()

        renderingListeners.values.forEach { listener in
            listener.send(self.rendering)
        }

        if let outputEvent = output.outputEvent {
            outputListeners.values.forEach { listener in
                listener.send(outputEvent)
            }
        }

        debugger?.didUpdate(
            snapshot: rootNode.makeDebugSnapshot(),
            updateInfo: output.debugInfo
        )

        rootNode.enableEvents()
    }
}

// MARK: - Separate listener types

open class Listener<OutputType> {
    public let id: UUID

    open func send(_ output: OutputType) {
        fatalError("This needs to be subclassed and implemented!")
    }

    public init(id: UUID = UUID()) {
        self.id = id
    }
}

public final class ClosureListener<OutputType>: Listener<OutputType> {
    private let listener: (OutputType) -> Void

    override public func send(_ output: OutputType) {
        listener(output)
    }

    public init(listener: @escaping (OutputType) -> Void) {
        self.listener = listener
        super.init()
    }
}

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
    private let debugger: WorkflowDebugger?

    private let (outputEvent, outputEventObserver) = Signal<WorkflowType.Output, Never>.pipe()

    private let rootNode: WorkflowNode<WorkflowType>

    private let mutableRendering: MutableProperty<WorkflowType.Rendering>

    /// Represents the `Rendering` produced by the root workflow in the hierarchy. New `Rendering` values are produced
    /// as state transitions occur within the hierarchy.
    public let rendering: Property<WorkflowType.Rendering>

    /// Initializes a new host with the given workflow at the root.
    ///
    /// - Parameter workflow: The root workflow in the hierarchy
    /// - Parameter debugger: An optional debugger. If provided, the host will notify the debugger of updates
    ///                       to the workflow hierarchy as state transitions occur.
    public init(workflow: WorkflowType, debugger: WorkflowDebugger? = nil) {
        self.debugger = debugger

        self.rootNode = WorkflowNode(workflow: workflow)

        self.mutableRendering = MutableProperty(rootNode.render(isRootNode: true))
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
            debugInfo: WorkflowUpdateDebugInfo(
                workflowType: "\(WorkflowType.self)",
                kind: .didUpdate(source: .external)
            )
        )
        handle(output: output)
    }

    private func handle(output: WorkflowNode<WorkflowType>.Output) {
        mutableRendering.value = rootNode.render(isRootNode: true)

        if let outputEvent = output.outputEvent {
            outputEventObserver.send(value: outputEvent)
        }

        debugger?.didUpdate(
            snapshot: rootNode.makeDebugSnapshot(),
            updateInfo: output.debugInfo
        )

        rootNode.enableEvents()
    }

    /// A signal containing output events emitted by the root workflow in the hierarchy.
    public var output: Signal<WorkflowType.Output, Never> {
        return outputEvent
    }
}

extension WorkflowHost {
    /// Initializes a new host with the given workflow at the root.
    ///
    /// - Parameter workflow: The root workflow in the hierarchy
    /// - Parameter debugger: An optional debugger. If provided, the host will notify the debugger of updates
    ///
    @_disfavoredOverload
    public convenience init<AnyWorkflowType: AnyWorkflowConvertible>(
        workflow: AnyWorkflowType,
        debugger: WorkflowDebugger? = nil
    ) where WorkflowType == AnyWorkflowWrapper<AnyWorkflowType.Rendering, AnyWorkflowType.Output> {
        self.init(workflow: AnyWorkflowWrapper(workflow), debugger: debugger)
    }
}

public typealias AnyWorkflowHost<Rendering, Output> = WorkflowHost<AnyWorkflowWrapper<Rendering, Output>>

/// A wrapper around an AnyWorkflow that allows consumers to create a WorkflowHost from an
/// `AnyWorkflowConvertible`.
public struct AnyWorkflowWrapper<Rendering, Output>: Workflow {
    public typealias State = Void
    public typealias Output = Output
    public typealias Rendering = Rendering

    var wrapped: AnyWorkflow<Rendering, Output>

    public init<W: AnyWorkflowConvertible>(_ wrapped: W) where W.Rendering == Rendering, W.Output == Output {
        self.wrapped = wrapped.asAnyWorkflow()
    }

    public func render(state: State, context: RenderContext<Self>) -> Rendering {
        return wrapped
            .mapOutput { AnyWorkflowAction(sendingOutput: $0) }
            .rendered(in: context)
    }
}

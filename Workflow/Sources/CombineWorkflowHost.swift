/*
 * Copyright 2022 Square Inc.
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

#if canImport(SwiftUI) && canImport(Combine) && swift(>=5.1)

    import Combine

    /// Manages an active workflow hierarchy.
    @available(iOS 13.0, macOS 10.15, *)
    public final class CombineWorkflowHost<WorkflowType: Workflow>: ObservableObject {
        private let debugger: WorkflowDebugger?

        private let outputSubject = PassthroughSubject<WorkflowType.Output, Never>()
        /// A publisher containing output events emitted by the root workflow in the hierarchy.
        public var output: AnyPublisher<WorkflowType.Output, Never> {
            return outputSubject.eraseToAnyPublisher()
        }

        private let rootNode: WorkflowNode<WorkflowType>

        /// Represents the `Rendering` produced by the root workflow in the hierarchy. New `Rendering` values are produced
        /// as state transitions occur within the hierarchy.
        @Published public private(set) var rendering: WorkflowType.Rendering

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

        private func handle(output: WorkflowNode<WorkflowType>.Output) {
            rendering = rootNode.render()

            if let outputEvent = output.outputEvent {
                outputSubject.send(outputEvent)
            }

            debugger?.didUpdate(
                snapshot: rootNode.makeDebugSnapshot(),
                updateInfo: output.debugInfo
            )

            rootNode.enableEvents()
        }
    }
#endif

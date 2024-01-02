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

/// Conforming types can be converted into `AnyWorkflow` values, allowing them to participate
/// in a workflow hierarchy.
public protocol AnyWorkflowConvertible<Rendering, Output> {
    /// The rendering type of this type's `AnyWorkflow` representation
    associatedtype Rendering

    /// The output type of this type's `AnyWorkflow` representation
    associatedtype Output

    /// Returns an `AnyWorkflow` representing this value.
    func asAnyWorkflow() -> AnyWorkflow<Rendering, Output>
}

extension AnyWorkflowConvertible {
    /// Creates or updates a child workflow of the given type, performs a render pass, and returns the result.
    ///
    /// Note that it is a programmer error to render two instances of a given workflow type with the same `key`
    /// during the same render pass.
    ///
    /// - Parameter context: The context with which the workflow will be rendered.
    /// - Parameter key: A string that uniquely identifies this workflow.
    ///
    /// - Returns: The `Rendering` generated by the workflow.
    public func rendered<Parent>(in context: RenderContext<Parent>, key: String = "") -> Rendering where Output: WorkflowAction, Output.WorkflowType == Parent {
        asAnyWorkflow().render(context: context, key: key, outputMap: { $0 })
    }

    public func rendered<Parent, Action>(in context: RenderContext<Parent>, key: String = "", outputMap: @escaping (Output) -> Action) -> Rendering where Action: WorkflowAction, Action.WorkflowType == Parent {
        asAnyWorkflow().render(context: context, key: key, outputMap: { outputMap($0) })
    }

    public func rendered<Parent>(in context: RenderContext<Parent>, key: String = "") -> Rendering where Output == AnyWorkflowAction<Parent> {
        asAnyWorkflow().render(context: context, key: key, outputMap: { $0 })
    }
}

extension AnyWorkflowConvertible where Output == Never {
    /// Creates or updates a child workflow of the given type, performs a render pass, and returns the result.
    ///
    /// Note that it is a programmer error to render two instances of a given workflow type with the same `key`
    /// during the same render pass.
    ///
    /// - Parameter context: The context with which the workflow will be rendered.
    /// - Parameter key: A string that uniquely identifies this workflow.
    ///
    /// - Returns: The `Rendering` generated by the workflow.
    public func rendered<T>(in context: RenderContext<T>, key: String = "") -> Rendering {
        // Convenience for workflow that have no output allowing them to be rendered with any context

        asAnyWorkflow()
            .render(
                context: context,
                key: key,
                outputMap: { _ -> AnyWorkflowAction<T> in }
            )
    }
}

extension AnyWorkflowConvertible where Rendering == Void {
    public func running<Parent, Action>(in context: RenderContext<Parent>, key: String = "", outputMap: @escaping (Output) -> Action) where Action: WorkflowAction, Action.WorkflowType == Parent {
        rendered(in: context, key: key, outputMap: outputMap)
    }
}

extension AnyWorkflowConvertible where Rendering == Void, Output: WorkflowAction {
    public func running<Parent>(in context: RenderContext<Parent>, key: String = "") where Output.WorkflowType == Parent {
        rendered(in: context, key: key)
    }
}

// MARK: -

extension AnyWorkflowConvertible {
    /// Process an `Output`
    ///
    /// - Parameter apply: On `Output`, mutate `State` as necessary and return new `Output` (or `nil`).
    public func onOutput<Parent>(_ apply: @escaping ((inout Parent.State, Output) -> Parent.Output?)) -> AnyWorkflow<Rendering, AnyWorkflowAction<Parent>> {
        asAnyWorkflow()
            .mapOutput { output in
                AnyWorkflowAction { state, _ -> Parent.Output? in
                    apply(&state, output)
                }
            }
    }
}

extension AnyWorkflowConvertible {
    /// Wraps this workflow in a workflow that ignores all outputs.
    ///
    /// - Returns: An `AnyWorkflow` with the same rendering and no output.
    public func ignoringOutput() -> AnyWorkflow<Rendering, Never> {
        OutputBlockingWorkflow(child: self).asAnyWorkflow()
    }
}

struct OutputBlockingWorkflow<Child: AnyWorkflowConvertible>: Workflow {
    typealias Output = Never
    typealias Rendering = Child.Rendering
    typealias State = Void

    var child: Child

    func render(state: Void, context: RenderContext<OutputBlockingWorkflow<Child>>) -> Child.Rendering {
        child
            .mapOutput { _ in AnyWorkflowAction.noAction }
            .rendered(in: context)
    }
}

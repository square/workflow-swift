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

/// A type-erased wrapper that contains a workflow with the given Rendering and Output types.
public struct AnyWorkflow<Rendering, Output> {
    @usableFromInline
    let storage: AnyStorage

    /// The underlying erased workflow instance
    @inlinable
    public var base: Any { storage.base }

    @usableFromInline
    init(storage: AnyStorage) {
        self.storage = storage
    }

    /// Initializes a new type-erased wrapper for the given workflow.
    @inlinable
    public init<T: Workflow>(_ workflow: T) where T.Rendering == Rendering, T.Output == Output {
        if let workflow = workflow as? AnyWorkflow<Rendering, Output> {
            self = workflow
        } else {
            self.init(storage: Storage<T>(
                workflow: workflow,
                renderingTransform: { $0 },
                outputTransform: { $0 }
            ))
        }
    }

    /// The underlying workflow's implementation type.
    public var workflowType: Any.Type {
        storage.workflowType
    }
}

extension AnyWorkflow: Workflow {
    public typealias Output = Output
    public typealias State = Void
    public typealias Rendering = Rendering

    @inlinable
    public func render(state: Void, context: RenderContext<AnyWorkflow<Rendering, Output>>) -> Rendering {
        storage.render(context: context, key: "") {
            AnyWorkflowAction(sendingOutput: $0)
        }
    }

    @inlinable
    public func asAnyWorkflow() -> AnyWorkflow<Rendering, Output> {
        self
    }
}

extension AnyWorkflow {
    /// Returns a new AnyWorkflow whose `Output` type has been transformed into the given type.
    ///
    /// - Parameter transform: An escaping closure that maps the original output type into the new output type.
    ///
    /// - Returns: A type erased workflow with the new output type (the rendering type remains unchanged).
    @inlinable
    public func mapOutput<NewOutput>(
        _ transform: @escaping (Output) -> NewOutput
    ) -> AnyWorkflow<Rendering, NewOutput> {
        let storage = storage.mapOutput(transform: transform)
        return AnyWorkflow<Rendering, NewOutput>(storage: storage)
    }

    /// Returns a new `AnyWorkflow` whose `Rendering` type has been transformed into the given type.
    ///
    /// - Parameter transform: An escaping closure that maps the original rendering type into the new rendering type.
    ///
    /// - Returns: A type erased workflow with the new rendering type (the output type remains unchanged).
    @inlinable
    public func mapRendering<NewRendering>(
        _ transform: @escaping (Rendering) -> NewRendering
    ) -> AnyWorkflow<NewRendering, Output> {
        let storage = storage.mapRendering(transform: transform)
        return AnyWorkflow<NewRendering, Output>(storage: storage)
    }

    /// Renders the underlying workflow implementation with the given context.
    ///
    /// We must invert the model here (by passing the context into the type, instead
    /// of passing the type into the context) because the type signature of the
    /// type-erased wrapper does not contain the underlying workflow's
    /// implementation type.
    ///
    /// That type information *is* present in our storage object, however, so we
    /// pass the context down to that storage object which will ultimately call
    /// through to `context.render(workflow:key:reducer:)`.
    @inlinable
    func render<Parent, Action: WorkflowAction>(
        context: RenderContext<Parent>,
        key: String,
        outputMap: @escaping (Output) -> Action
    ) -> Rendering where Action.WorkflowType == Parent {
        storage.render(context: context, key: key, outputMap: outputMap)
    }
}

extension AnyWorkflow {
    /// This is the type erased outer API (referenced by the containing AnyWorkflow).
    ///
    /// This type is never used directly.
    @usableFromInline
    class AnyStorage {
        @usableFromInline
        var base: Any { fatalError() }

        @usableFromInline
        func render<Parent, Action: WorkflowAction>(
            context: RenderContext<Parent>,
            key: String,
            outputMap: @escaping (Output) -> Action
        ) -> Rendering where Action.WorkflowType == Parent {
            fatalError()
        }

        @usableFromInline
        func mapRendering<NewRendering>(transform: @escaping (Rendering) -> NewRendering) -> AnyWorkflow<NewRendering, Output>.AnyStorage {
            fatalError()
        }

        @usableFromInline
        func mapOutput<NewOutput>(transform: @escaping (Output) -> NewOutput) -> AnyWorkflow<Rendering, NewOutput>.AnyStorage {
            fatalError()
        }

        @usableFromInline
        var workflowType: Any.Type {
            fatalError()
        }
    }

    /// Subclass that adds type information about the underlying workflow implementation.
    ///
    /// This is the only type that is ever actually used by AnyWorkflow as storage.
    @usableFromInline
    final class Storage<T: Workflow>: AnyStorage {
        let workflow: T
        let renderingTransform: (T.Rendering) -> Rendering
        let outputTransform: (T.Output) -> Output

        @usableFromInline
        init(workflow: T, renderingTransform: @escaping (T.Rendering) -> Rendering, outputTransform: @escaping (T.Output) -> Output) {
            self.workflow = workflow
            self.renderingTransform = renderingTransform
            self.outputTransform = outputTransform
        }

        override var base: Any { workflow }

        override var workflowType: Any.Type {
            T.self
        }

        override func render<Parent, Action: WorkflowAction>(
            context: RenderContext<Parent>,
            key: String,
            outputMap: @escaping (Output) -> Action
        ) -> Rendering where Action.WorkflowType == Parent {
            let outputMap: (T.Output) -> Action = { [outputTransform] output in
                outputMap(outputTransform(output))
            }
            let rendering = context.render(workflow: workflow, key: key, outputMap: outputMap)
            return renderingTransform(rendering)
        }

        override func mapOutput<NewOutput>(transform: @escaping (Output) -> NewOutput) -> AnyWorkflow<Rendering, NewOutput>.AnyStorage {
            AnyWorkflow<Rendering, NewOutput>.Storage<T>(
                workflow: workflow,
                renderingTransform: renderingTransform,
                outputTransform: { [outputTransform] in
                    transform(outputTransform($0))
                }
            )
        }

        override func mapRendering<NewRendering>(transform: @escaping (Rendering) -> NewRendering) -> AnyWorkflow<NewRendering, Output>.AnyStorage {
            AnyWorkflow<NewRendering, Output>.Storage<T>(
                workflow: workflow,
                renderingTransform: { [renderingTransform] in
                    transform(renderingTransform($0))
                },
                outputTransform: outputTransform
            )
        }
    }
}

extension AnyWorkflowConvertible {
    @inlinable
    public func mapOutput<NewOutput>(_ transform: @escaping (Output) -> NewOutput) -> AnyWorkflow<Rendering, NewOutput> {
        asAnyWorkflow().mapOutput(transform)
    }

    @inlinable
    public func mapRendering<NewRendering>(_ transform: @escaping (Rendering) -> NewRendering) -> AnyWorkflow<NewRendering, Output> {
        asAnyWorkflow().mapRendering(transform)
    }
}

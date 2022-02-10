//
//  Publisher+Extensions.swift
//  WorkflowCombine
//
//  Created by Soo Rin Park on 11/3/21.
//

#if canImport(Combine) && swift(>=5.1)

    import Combine
    import Foundation
    import Workflow

    @available(iOS 13.0, macOS 10.15, *)
    /// This is a workaround to the fact you extensions of protocols cannot have an inheritance clause.
    /// a previous solution had extending the `AnyPublisher` to conform to `AnyWorkflowConvertible`,
    /// but was limited in the fact that rendering was only available to `AnyPublisher`s.
    /// this solutions makes it so that all publishers can render its view.
    extension Publisher where Failure == Never {
        public func running<Parent>(in context: RenderContext<Parent>, key: String = "") where
            Output == AnyWorkflowAction<Parent> {
            asAnyWorkflow().rendered(in: context, key: key, outputMap: { $0 })
        }

        public func mapOutput<NewOutput>(_ transform: @escaping (Output) -> NewOutput) -> AnyWorkflow<Void, NewOutput> {
            asAnyWorkflow().mapOutput(transform)
        }

        func asAnyWorkflow() -> AnyWorkflow<Void, Output> {
            PublisherWorkflow(publisher: self).asAnyWorkflow()
        }
    }

//    @available(iOS 13.0, macOS 10.15, *)
//    extension WorkflowHost {
//        public var renderPublisher: AnyPublisher<WorkflowType.Rendering, Never> {
//            let passthrough = PassthroughSubject<WorkflowType.Rendering, Never>()
//            renderingListener = { render in
//                passthrough.send(render)
//            }
//            return passthrough.eraseToAnyPublisher()
//        }
//    }

//    @available(iOS 13.0, macOS 10.15, *)
//    public final class PublisherListener<WorkflowType: Workflow>: Listener {
//        public typealias Rendering = WorkflowType.Rendering
//        public typealias Output = WorkflowType.Output
//
//        public var renderPublisher: AnyPublisher<Rendering, Never> {
//            return renderSubject.eraseToAnyPublisher()
//        }
//        public var outputPublisher: AnyPublisher<Output, Never> {
//            return outputSubject.eraseToAnyPublisher()
//        }
//
//        private let renderSubject = PassthroughSubject<Rendering, Never>()
//        private let outputSubject = PassthroughSubject<Output, Never>()
//
//        public func render(render: WorkflowType.Rendering) {
//            renderSubject.send(render)
//        }
//
//        public func output(output: WorkflowType.Output) {
//            outputSubject.send(output)
//        }
//    }

    // Combine publisher listener implemenation
    @available(iOS 13.0, macOS 10.15, *)
    public final class WorkflowPublisherListener<WorkflowType: Workflow>: WorkflowListener<WorkflowType> {
        public var renderPublisher: AnyPublisher<WorkflowType.Rendering, Never> {
            return renderingSubject.eraseToAnyPublisher()
        }

        public var outputPublisher: AnyPublisher<WorkflowType.Output, Never> {
            return outputSubject.eraseToAnyPublisher()
        }

        private let renderingSubject = PassthroughSubject<WorkflowType.Rendering, Never>()
        private let outputSubject = PassthroughSubject<WorkflowType.Output, Never>()

        override public func rendering(rendering: WorkflowType.Rendering) {
            renderingSubject.send(rendering)
        }

        override public func output(output: WorkflowType.Output) {
            outputSubject.send(output)
        }
    }

    // Separate listeners
    @available(iOS 13.0, macOS 10.15, *)
    public final class PublisherRenderingListener<WorkflowType: Workflow>: RenderingListener<WorkflowType> {
        public var renderingPublisher: AnyPublisher<WorkflowType.Rendering, Never> {
            return renderingSubject.eraseToAnyPublisher()
        }

        private let renderingSubject = PassthroughSubject<WorkflowType.Rendering, Never>()

        override public func rendering(rendering: WorkflowType.Rendering) {
            renderingSubject.send(rendering)
        }
    }

    @available(iOS 13.0, macOS 10.15, *)
    public final class PublisherOutputListener<WorkflowType: Workflow>: OutputListener<WorkflowType> {
        public var outputPublisher: AnyPublisher<WorkflowType.Output, Never> {
            return outputSubject.eraseToAnyPublisher()
        }

        private let outputSubject = PassthroughSubject<WorkflowType.Output, Never>()

        override public func output(output: WorkflowType.Output) {
            outputSubject.send(output)
        }
    }
#endif

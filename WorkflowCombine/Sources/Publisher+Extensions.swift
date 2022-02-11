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

    private enum WorkflowCombineListenerIdentifier {
        static let id = UUID()
    }

    @available(iOS 13.0, macOS 10.15, *)
    final class PublisherListener<OutputType>: Listener<OutputType> {
        var publisher: AnyPublisher<OutputType, Never> {
            return subject.eraseToAnyPublisher()
        }

        private let subject = PassthroughSubject<OutputType, Never>()

        override public func send(_ output: OutputType) {
            subject.send(output)
        }

        public init() {
            super.init(id: WorkflowCombineListenerIdentifier.id)
        }
    }

    @available(iOS 13.0, macOS 10.15, *)
    extension WorkflowHost {
        public var renderingPublisher: AnyPublisher<WorkflowType.Rendering, Never> {
            if let publisher = getRenderingListener(id: WorkflowCombineListenerIdentifier.id) as? PublisherListener {
                return publisher.publisher
            } else {
                let listener = PublisherListener<WorkflowType.Rendering>()
                addRenderingListener(listener: listener)
                return listener.publisher
            }
        }

        public var outputPublisher: AnyPublisher<WorkflowType.Output, Never> {
            if let publisher = getOutputListener(id: WorkflowCombineListenerIdentifier.id) as? PublisherListener {
                return publisher.publisher
            } else {
                let listener = PublisherListener<WorkflowType.Output>()
                addOutputListener(listener: listener)
                return listener.publisher
            }
        }
    }
#endif

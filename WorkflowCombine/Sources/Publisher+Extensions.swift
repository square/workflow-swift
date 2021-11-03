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

#endif

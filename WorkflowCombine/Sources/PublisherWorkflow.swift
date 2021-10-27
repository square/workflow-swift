/*
 * Copyright 2021 Square Inc.
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

#if canImport(Combine) && swift(>=5.1)

    import Combine
    import Foundation
    import Workflow

    @available(iOS 13.0, macOS 10.15, *)
    extension AnyPublisher: AnyWorkflowConvertible where Failure == Never {
        public func asAnyWorkflow() -> AnyWorkflow<Void, Output> {
            return PublisherWorkflow(publisher: self).asAnyWorkflow()
        }
    }

    @available(iOS 13.0, macOS 10.15, *)
    struct PublisherWorkflow<Value>: Workflow {
        public typealias Output = Value
        public typealias State = Void
        public typealias Rendering = Void

        let publisher: AnyPublisher<Output, Never>

        public init(publisher: AnyPublisher<Output, Never>) {
            self.publisher = publisher
        }

        public func render(state: State, context: RenderContext<Self>) -> Rendering {
            let sink = context.makeSink(of: AnyWorkflowAction.self)
            context.runSideEffect(key: "") { [publisher] lifetime in
                _ = publisher
                    .map { AnyWorkflowAction(sendingOutput: $0) }
                    .subscribe(on: RunLoop.main)
                    .sink { sink.send($0) }
            }
        }
    }

#endif

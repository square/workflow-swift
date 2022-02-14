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

#if canImport(Combine) && swift(>=5.1)

    import Combine
    import Foundation
    import Workflow

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

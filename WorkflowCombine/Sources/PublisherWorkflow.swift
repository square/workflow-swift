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

#if canImport(Combine)

import Combine
import Foundation
import Workflow

struct PublisherWorkflow<WorkflowPublisher: Publisher>: Workflow where WorkflowPublisher.Failure == Never {
    typealias Output = WorkflowPublisher.Output
    typealias State = Void
    typealias Rendering = Void

    let publisher: WorkflowPublisher

    init(publisher: WorkflowPublisher) {
        self.publisher = publisher
    }

    func render(state: State, context: RenderContext<Self>) -> Rendering {
        let sink = context.makeSink(of: AnyWorkflowAction.self)
        context.runSideEffect(key: "") { [publisher] lifetime in
            let cancellable = publisher
                .map { AnyWorkflowAction(sendingOutput: $0) }
                .receive(on: DispatchQueue.main)
                .sink { sink.send($0) }

            lifetime.onEnded {
                cancellable.cancel()
            }
        }
    }
}

#endif

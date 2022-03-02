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

import Combine
import Foundation
import Workflow

@available(iOS 13.0, macOS 10.15, *)
extension Task: AnyWorkflowConvertible where Failure == Never {
    public func asAnyWorkflow() -> AnyWorkflow<Void, Success> {
        TaskWorkflow(taskProvider: { self }).asAnyWorkflow()
    }
}

@available(iOS 13.0, macOS 10.15, *)
struct TaskWorkflow<Value>: Workflow {
    public typealias Output = Value
    public typealias State = Void
    public typealias Rendering = Void

    var taskProvider: () -> Task<Value, Never>

    public init(taskProvider: @escaping () -> Task<Value, Never>) {
        self.taskProvider = taskProvider
    }

    public func render(state: State, context: RenderContext<TaskWorkflow>) -> Rendering {
        let sink = context.makeSink(of: AnyWorkflowAction.self)
        context.runSideEffect(key: "") { [taskProvider] lifetime in
            let providedTask = taskProvider()
            let task = Task {
                let output = await providedTask.value
                if Task.isCancelled { return }
                let action = AnyWorkflowAction<TaskWorkflow>(sendingOutput: output)
                DispatchQueue.main.async {
                    sink.send(action)
                }
            }

            lifetime.onEnded {
                task.cancel()
                providedTask.cancel()
            }
        }
    }
}

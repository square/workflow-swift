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

#if DEBUG

    @testable import Workflow

    extension RenderTester {
        internal class AnyExpectedWorkflow {
            let workflowType: Any.Type
            let key: String
            fileprivate init(workflowType: Any.Type, key: String) {
                self.workflowType = workflowType
                self.key = key
            }
        }

        internal class ExpectedWorkflow<ExpectedWorkflowType: Workflow>: AnyExpectedWorkflow {
            let rendering: ExpectedWorkflowType.Rendering
            let output: ExpectedWorkflowType.Output?

            init(key: String, rendering: ExpectedWorkflowType.Rendering, output: ExpectedWorkflowType.Output?) {
                self.rendering = rendering
                self.output = output
                super.init(workflowType: ExpectedWorkflowType.self, key: key)
            }
        }
    }

    extension RenderTester {
        internal class AnyExpectedWorker {
            let erasedWorker: Any
            let workerType: Any.Type
            fileprivate init(workerType: Any.Type, erasedWorker: Any) {
                self.workerType = workerType
                self.erasedWorker = erasedWorker
            }
        }

        internal final class ExpectedWorker<WorkerType: Worker>: AnyExpectedWorker {
            let worker: WorkerType
            let output: WorkerType.Output?

            internal init(worker: WorkerType, output: WorkerType.Output?) {
                self.worker = worker
                self.output = output
                super.init(workerType: WorkerType.self, erasedWorker: worker)
            }
        }
    }

    extension RenderTester {
        internal class ExpectedSideEffect<WorkflowType: Workflow> {
            let key: AnyHashable

            init(key: AnyHashable) {
                self.key = key
            }

            func apply<ContextType>(context: ContextType) where ContextType: RenderContextType, ContextType.WorkflowType == WorkflowType {}
        }

        internal final class ExpectedSideEffectWithAction<WorkflowType, ActionType: WorkflowAction>: ExpectedSideEffect<WorkflowType> where ActionType.WorkflowType == WorkflowType {
            let action: ActionType

            internal init(key: AnyHashable, action: ActionType) {
                self.action = action
                super.init(key: key)
            }

            override func apply<ContextType>(context: ContextType) where ContextType: RenderContextType, ContextType.WorkflowType == WorkflowType {
                let sink = context.makeSink(of: ActionType.self)
                sink.send(action)
            }
        }
    }

#endif

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
        let file: StaticString
        let line: UInt

        fileprivate init(workflowType: Any.Type, key: String, file: StaticString, line: UInt) {
            self.workflowType = workflowType
            self.key = key
            self.file = file
            self.line = line
        }
    }

    internal class ExpectedWorkflow<ExpectedWorkflowType: Workflow>: AnyExpectedWorkflow {
        let rendering: ExpectedWorkflowType.Rendering
        let output: ExpectedWorkflowType.Output?
        let assertions: (ExpectedWorkflowType) -> Void

        init(key: String, rendering: ExpectedWorkflowType.Rendering, output: ExpectedWorkflowType.Output?, assertions: @escaping (ExpectedWorkflowType) -> Void = { _ in }, file: StaticString, line: UInt) {
            self.rendering = rendering
            self.output = output
            self.assertions = assertions
            super.init(workflowType: ExpectedWorkflowType.self, key: key, file: file, line: line)
        }
    }
}

extension RenderTester {
    internal class ExpectedSideEffect {
        let key: AnyHashable
        let file: StaticString
        let line: UInt

        init(key: AnyHashable, file: StaticString, line: UInt) {
            self.key = key
            self.file = file
            self.line = line
        }

        func apply<ContextType>(context: ContextType) where ContextType: RenderContextType, ContextType.WorkflowType == WorkflowType {}
    }

    internal final class ExpectedSideEffectWithAction<ActionType: WorkflowAction>: ExpectedSideEffect where ActionType.WorkflowType == WorkflowType {
        let action: ActionType

        internal init(key: AnyHashable, action: ActionType, file: StaticString, line: UInt) {
            self.action = action
            super.init(key: key, file: file, line: line)
        }

        override func apply<ContextType>(context: ContextType) where ContextType: RenderContextType, ContextType.WorkflowType == WorkflowType {
            let sink = context.makeSink(of: ActionType.self)
            sink.send(action)
        }
    }
}

#endif

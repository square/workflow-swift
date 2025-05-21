/*
 * Copyright Square Inc.
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

import Testing

@testable import Workflow

@MainActor
struct ApplyContextTests {
    @Test
    func concreteApplyContextInvalidatedAfterUse() async throws {
        var escapedContext: ApplyContext<EscapingContextWorkflow>?
        let onApply = { (context: ApplyContext<EscapingContextWorkflow>) in
            #expect(context[workflowValue: \.property] == 42)
            #expect(context.concreteStorage != nil)
            escapedContext = context
        }

        let workflow = EscapingContextWorkflow(
            property: 42,
            onApply: onApply
        )
        let node = WorkflowNode(workflow: workflow)

        let emitEvent = node.render()
        node.enableEvents()

        emitEvent()

        #expect(escapedContext != nil)
        #expect(escapedContext?.concreteStorage == nil)
    }
}

// MARK: -

private struct EscapingContextWorkflow: Workflow {
    typealias Rendering = () -> Void
    typealias State = Void

    var property: Int
    var onApply: ((ApplyContext<Self>) -> Void)?

    func render(
        state: State,
        context: RenderContext<EscapingContextWorkflow>
    ) -> Rendering {
        let sink = context.makeSink(of: EscapingAction.self)
        let action = EscapingAction(onApply: onApply)
        return { sink.send(action) }
    }

    struct EscapingAction: WorkflowActionBase {
        typealias WorkflowType = EscapingContextWorkflow

        var onApply: ((ApplyContext<WorkflowType>) -> Void)?

        func apply(
            toState state: inout WorkflowType.State,
            context: ApplyContext<WorkflowType>
        ) -> WorkflowType.Output? {
            onApply?(context)
            return nil
        }
    }
}

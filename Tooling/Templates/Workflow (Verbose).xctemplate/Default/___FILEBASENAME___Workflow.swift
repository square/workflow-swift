//  ___FILEHEADER___

import Workflow
import WorkflowUI

// MARK: Input and Output

struct ___VARIABLE_productName___Workflow: Workflow {
    enum Output {}
}

// MARK: State and Initialization

extension ___VARIABLE_productName___Workflow {
    struct State {}

    func makeInitialState() -> ___VARIABLE_productName___Workflow.State {
        return State()
    }

    func workflowDidChange(from previousWorkflow: ___VARIABLE_productName___Workflow, state: inout State) {}
}

// MARK: Actions

extension ___VARIABLE_productName___Workflow {
    enum Action: WorkflowAction {
        typealias WorkflowType = ___VARIABLE_productName___Workflow

        func apply(toState state: inout ___VARIABLE_productName___Workflow.State) -> ___VARIABLE_productName___Workflow.Output? {
            switch self {
                // Update state and produce an optional output based on which action was received.
            }
        }
    }
}

// MARK: Rendering

extension ___VARIABLE_productName___Workflow {
    // TODO: Change this to your actual rendering type
    typealias Rendering = String

    func render(state: ___VARIABLE_productName___Workflow.State, context: RenderContext<___VARIABLE_productName___Workflow>) -> Rendering {
        #warning("Don't forget your render implementation and to return the correct rendering type!")
        return "This is likely not the rendering that you want to return"
    }
}

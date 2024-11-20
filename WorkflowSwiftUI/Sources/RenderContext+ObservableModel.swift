import Foundation
import Workflow

extension RenderContext where WorkflowType.State: ObservableState {
    /// Creates a ``StateAccessor`` for this workflow's state.
    ///
    /// ``StateAccessor`` is used by ``ObservableModel`` to read and write observable state. A state
    /// accessor can serve as the ``ObservableModel`` implementation for simple workflows with no
    /// actions. State updates will be sent to the workflow's state mutation sink.
    public func makeStateAccessor(
        state: WorkflowType.State
    ) -> StateAccessor<WorkflowType.State> {
        StateAccessor(state: state, sendValue: makeStateMutationSink().send)
    }

    /// Creates an ``ActionModel`` for this workflow's state and action.
    ///
    /// ``ActionModel`` is a simple ``ObservableModel`` implementation for workflows with one action
    /// type. For more complex workflows with multiple actions, you can create a custom model that
    /// conforms to ``ObservableModel``. For less complex workflows, you can use
    /// ``makeStateAccessor(state:)`` instead. See ``ObservableModel`` for more information.
    public func makeActionModel<Action: WorkflowAction>(
        state: WorkflowType.State
    ) -> ActionModel<WorkflowType.State, Action>
        where Action.WorkflowType == WorkflowType
    {
        ActionModel(
            accessor: makeStateAccessor(state: state),
            sendAction: makeSink(of: Action.self).send
        )
    }
}

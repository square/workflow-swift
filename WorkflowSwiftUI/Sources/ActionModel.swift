import WorkflowMacrosSupport

/// An ``ObservableModel`` for workflows with a single action.
///
/// To create an accessor, use
/// ``Workflow/RenderContext/makeActionModel(state:)``. State writes and actions
/// will be sent to the workflow.
public struct ActionModel<State: ObservableState, Action>: ObservableModel, SingleActionModel {
    public let accessor: StateAccessor<State>
    public let sendAction: (Action) -> Void

    /// Creates a new ActionModel.
    ///
    /// Rather than creating this model directly, you should usually use the
    /// ``Workflow/RenderContext/makeActionModel(state:)`` method to create an
    /// instance of this model. If you need a static model for testing or
    /// previews, you can use the ``constant(state:)`` method.
    public init(accessor: StateAccessor<State>, sendAction: @escaping (Action) -> Void) {
        self.accessor = accessor
        self.sendAction = sendAction
    }
}

/// An observable model with a single action.
///
/// Conforming to this type provides some convenience methods for sending actions to the model. You
/// can use ``ActionModel`` rather than conforming yourself.
public protocol SingleActionModel: ObservableModel {
    associatedtype Action

    var sendAction: (Action) -> Void { get }
}

extension ActionModel: Identifiable where State: Identifiable {
    public var id: State.ID {
        accessor.id
    }
}

#if DEBUG

extension ActionModel {
    /// Creates a static model which ignores all sent values, suitable for static previews
    /// or testing.
    public static func constant(state: State) -> ActionModel<State, Action> {
        ActionModel(accessor: .constant(state: state), sendAction: { _ in })
    }
}

#endif

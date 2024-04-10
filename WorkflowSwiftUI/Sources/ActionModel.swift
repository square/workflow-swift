/// An ``ObservableModel`` for workflows with a single action.
///
/// Rather than creating this model directly, you should use the
/// ``Workflow/RenderContext/makeActionModel(state:)`` method to create an instance of this model.
public struct ActionModel<State: ObservableState, Action>: ObservableModel, SingleActionModel {
    public let accessor: StateAccessor<State>
    public let sendAction: (Action) -> Void
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

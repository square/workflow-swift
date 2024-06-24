/// A wrapper around observable state that provides read and write access through unidirectional
/// channels.
///
/// This type serves as the primary channel of information in an ``ObservableModel``, by providing
/// read and write access to state through separate mechanisms.
///
/// To create an accessor, use ``Workflow/RenderContext/makeStateAccessor(state:)``. State writes
/// will flow through a workflow's state mutation sink.
///
/// This type can be embedded in an ``ObservableModel`` or used directly, for trivial workflows with
/// no custom actions.
public struct StateAccessor<State: ObservableState> {
    let state: State
    let sendValue: (@escaping (inout State) -> Void) -> Void
}

extension StateAccessor: ObservableModel {
    public var accessor: StateAccessor<State> { self }
}

extension StateAccessor: Identifiable where State: Identifiable {
    public var id: State.ID {
        state.id
    }
}

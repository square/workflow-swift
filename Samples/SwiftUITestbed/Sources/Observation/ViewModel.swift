import ComposableArchitecture

struct ViewModel<State: ObservableState, Action> {
    let state: State
    let sendAction: (Action) -> Void
}

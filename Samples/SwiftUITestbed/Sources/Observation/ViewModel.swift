import ComposableArchitecture
import Workflow

struct ViewModel<State: ObservableState, Action> {
    let state: State
    let sendAction: (Action) -> Void
    let sendValue: (@escaping (inout State) -> Void) -> Void
}

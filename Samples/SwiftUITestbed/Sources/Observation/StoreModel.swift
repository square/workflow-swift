import ComposableArchitecture
import Workflow

struct StoreModel<State: ObservableState, Action>: ObservableModel {
    let state: State
    let sendAction: (Action) -> Void
    let sendValue: (@escaping (inout State) -> Void) -> Void

    var model: StoreModel<State, Action> {
        self
    }
}

protocol ObservableModel<State, Action> {
    associatedtype State: ObservableState
    associatedtype Action

    var model: StoreModel<State, Action> { get }
}

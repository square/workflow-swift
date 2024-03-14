import ComposableArchitecture
import Workflow

@dynamicMemberLookup
protocol ObservableModel<State> {
    associatedtype State: ObservableState

    var lens: StateLens<State> { get }
}

extension ObservableModel {
    subscript<T>(dynamicMember keyPath: WritableKeyPath<State, T>) -> T {
        get {
            lens.state[keyPath: keyPath]
        }
        set {
            lens.sendValue { $0[keyPath: keyPath] = newValue }
        }
    }
}

protocol ActionModel {
    associatedtype Action

    var sendAction: (Action) -> Void { get }
}

// Simplest form of model, with no actions
struct StateLens<State: ObservableState> {
    let state: State
    let sendValue: (@escaping (inout State) -> Void) -> Void
}

extension StateLens: ObservableModel {
    var lens: StateLens<State> { self }
}

// A common model with 1 action
struct StoreModel<State: ObservableState, Action>: ObservableModel, ActionModel {
    let lens: StateLens<State>
    let sendAction: (Action) -> Void
}

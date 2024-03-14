import ComposableArchitecture
import Workflow

@dynamicMemberLookup
protocol ObservableModel<State> {
    associatedtype State: ObservableState

    var accessor: StateAccessor<State> { get }
}

extension ObservableModel {
    subscript<T>(dynamicMember keyPath: WritableKeyPath<State, T>) -> T {
        get {
            accessor.state[keyPath: keyPath]
        }
        // If desirable, we could further divide this into a read-only and a writable version.
        set {
            accessor.sendValue { $0[keyPath: keyPath] = newValue }
        }
    }
}

protocol ActionModel {
    associatedtype Action

    var sendAction: (Action) -> Void { get }
}

// Simplest form of model, with no actions
struct StateAccessor<State: ObservableState> {
    let state: State
    let sendValue: (@escaping (inout State) -> Void) -> Void
}

extension StateAccessor: ObservableModel {
    var accessor: StateAccessor<State> { self }
}

// A common model with 1 action
struct StoreModel<State: ObservableState, Action>: ObservableModel, ActionModel {
    let accessor: StateAccessor<State>
    let sendAction: (Action) -> Void
}

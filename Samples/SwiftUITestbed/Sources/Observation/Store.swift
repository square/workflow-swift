import ComposableArchitecture // for ObservableState and Perception

@dynamicMemberLookup
public final class Store<State: ObservableState>: Perceptible {
    private var _state: State
    let _$observationRegistrar = PerceptionRegistrar()

    fileprivate(set) var state: State {
        get {
            _$observationRegistrar.access(self, keyPath: \.state)
            return _state
        }
        set {
            if !_$isIdentityEqual(state, newValue) {
                _$observationRegistrar.withMutation(of: self, keyPath: \.state) {
                    _state = newValue
                }
            } else {
                _state = newValue
            }
        }
    }

    private init(state: State) {
        self._state = state
    }
}

public extension Store {
    static func make(initialState: State) -> (Store, (State) -> Void) {
        let store = Store(state: initialState)
        let setState = { store.state = $0 }
        return (store, setState)
    }

    subscript<T>(dynamicMember keyPath: KeyPath<State, T>) -> T {
        state[keyPath: keyPath]
    }
}

extension Store: Equatable {
    public static func == (lhs: Store, rhs: Store) -> Bool {
        lhs === rhs
    }
}

extension Store: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

extension Store: Identifiable {}

#if canImport(Observation)
import Observation

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension Store: Observable {}
#endif

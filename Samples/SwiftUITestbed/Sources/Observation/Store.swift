import ComposableArchitecture // for ObservableState and Perception

@dynamicMemberLookup
final class Store<State: ObservableState, Action>: Perceptible {
    typealias Model = ViewModel<State, Action>

    private var model: Model
    private let _$observationRegistrar = PerceptionRegistrar()

    var state: State {
        _$observationRegistrar.access(self, keyPath: \.state)
        return model.state
    }

    func send(_ action: Action) {
        model.sendAction(action)
    }

    fileprivate init(_ model: Model) {
        self.model = model
    }

    fileprivate func setModel(_ newValue: Model) {
        if !_$isIdentityEqual(model.state, newValue.state) {
            _$observationRegistrar.withMutation(of: self, keyPath: \.state) {
                model = newValue
            }
        } else {
            model = newValue
        }
    }
}

extension Store {
    static func make(model: Model) -> (Store, (Model) -> Void) {
        let store = Store(model)
        return (store, store.setModel)
    }

    subscript<T>(dynamicMember keyPath: KeyPath<State, T>) -> T {
        state[keyPath: keyPath]
    }

    func action(_ action: Action) -> () -> Void {
        { self.send(action) }
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

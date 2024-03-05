import ComposableArchitecture // for ObservableState and Perception
import SwiftUI

@dynamicMemberLookup
final class Store<State: ObservableState, Action>: Perceptible {
    typealias Model = ViewModel<State, Action>

    private var model: Model
    private let _$observationRegistrar = PerceptionRegistrar()

    private var bindings: [BindingKey: Any] = [:]

    var state: State {
        _$observationRegistrar.access(self, keyPath: \.state)
        return model.state
    }

    func send(_ action: Action) {
        model.sendAction(action)
    }

    private func send<Value>(keyPath: WritableKeyPath<State, Value>, value: Value) {
        print("Store.send(\(keyPath), \(value))")
        model.sendValue { state in
            state[keyPath: keyPath] = value
        }
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

    subscript<T>(dynamicMember keyPath: WritableKeyPath<State, T>) -> T {
        get {
            state[keyPath: keyPath]
        }
        set {
            send(keyPath: keyPath, value: newValue)
        }
    }

    func action(_ action: Action) -> () -> Void {
        { self.send(action) }
    }

    func binding<Value>(
        for keyPath: ReferenceWritableKeyPath<Store<State, Action>, Value>
    ) -> Binding<Value> {
        let key = BindingKey(keyPath: keyPath, action: nil)

        if let binding = bindings[key] as? Binding<Value> {
            print("cached binding for \(keyPath)")
            return binding
        }

        print("new binding for \(keyPath)")
        let binding = Binding(
            get: { self[keyPath: keyPath] },
            set: { self[keyPath: keyPath] = $0 }
        )

        bindings[key] = binding

        return binding

    }

    func binding<Value>(
        for keyPath: KeyPath<State, Value>,
        action: CaseKeyPath<Action, Value>
    ) -> Binding<Value> {
        let key = BindingKey(keyPath: keyPath, action: action)

        if let binding = bindings[key] as? Binding<Value> {
            print("cached binding for \(keyPath)")
            return binding
        }

        print("new binding for \(keyPath)")
        let binding = Binding(
            get: { self.state[keyPath: keyPath] },
            set: { self.send(action($0)) }
        )

        bindings[key] = binding

        return binding
    }

    struct BindingKey: Hashable {
        let keyPath: AnyKeyPath
        let action: AnyKeyPath?
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

import ComposableArchitecture // for ObservableState and Perception
import SwiftUI

@dynamicMemberLookup
final class Store<Model: ObservableModel>: Perceptible {
    typealias State = Model.State

    private var model: Model
    private let _$observationRegistrar = PerceptionRegistrar()

    private var bindings: [BindingKey: Any] = [:]
    private var childStores: [AnyKeyPath: ChildStore] = [:]

    var state: State {
        _$observationRegistrar.access(self, keyPath: \.state)
        return model.lens.state
    }

    private func send<Value>(keyPath: WritableKeyPath<State, Value>, value: Value) {
        print("Store.send(\(keyPath), \(value))")
        model.lens.sendValue { state in
            state[keyPath: keyPath] = value
        }
    }

    fileprivate init(_ model: Model) {
        self.model = model
    }

    fileprivate func setModel(_ newValue: Model) {
        if !_$isIdentityEqual(model.lens.state, newValue.lens.state) {
            _$observationRegistrar.withMutation(of: self, keyPath: \.state) {
                model = newValue
            }
        } else {
            model = newValue
        }

        for childStore in childStores.values {
            childStore.setModel(newValue)
        }
    }
}

extension Store where Model: ActionModel {
    typealias Action = Model.Action

    func action(_ action: Action) -> () -> Void {
        { self.send(action) }
    }

    func send(_ action: Action) {
        model.sendAction(action)
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

    func scope<ChildModel>(keyPath: KeyPath<Model, ChildModel>) -> Store<ChildModel> {
        if let childStore = childStores[keyPath]?.store as? Store<ChildModel> {
            return childStore
        }

        let childModel = model[keyPath: keyPath]
        let childStore = Store<ChildModel>(childModel)

        childStores[keyPath] = ChildStore(store: childStore, setModel: { model in
            childStore.setModel(model[keyPath: keyPath])
        })

        return childStore
    }

    // TODO: child stores for optionals, collections, etc

    subscript<ChildModel: ObservableModel>(dynamicMember keyPath: KeyPath<Model, ChildModel>) -> Store<ChildModel> {
        scope(keyPath: keyPath)
    }

    struct ChildStore {
        var store: Any
        var setModel: (Model) -> Void
    }

    func binding<Value>(
        for keyPath: ReferenceWritableKeyPath<Store<Model>, Value>
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

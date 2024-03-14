import ComposableArchitecture // for ObservableState and Perception
import SwiftUI
import Workflow

@dynamicMemberLookup
final class Store<Model: ObservableModel>: Perceptible {
    typealias State = Model.State

    private var model: Model
    private let _$observationRegistrar = PerceptionRegistrar()

    private var bindings: [BindingKey: Any] = [:]
    private var childStores: [AnyKeyPath: ChildStore] = [:]

    var state: State {
        _$observationRegistrar.access(self, keyPath: \.state)
        return model.accessor.state
    }

    private func send<Value>(keyPath: WritableKeyPath<State, Value>, value: Value) {
        print("Store.send(\(keyPath), \(value))")
        model.accessor.sendValue { state in
            state[keyPath: keyPath] = value
        }
    }

    fileprivate init(_ model: Model) {
        self.model = model
    }

    fileprivate func setModel(_ newValue: Model) {
        if !_$isIdentityEqual(model.accessor.state, newValue.accessor.state) {
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
        // \Model.sendAction is not ideal for "sink path" but unique for prototyping
        binding(key: .keyPathSinkAction(keyPath: keyPath, sinkPath: \Model.sendAction, actionPath: action)) {
            Binding(
                get: { self.state[keyPath: keyPath] },
                set: { self.send(action($0)) }
            )
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

    subscript<Action>(dynamicMember keyPath: KeyPath<Model, Sink<Action>>) -> Sink<Action> {
        model[keyPath: keyPath]
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
        binding(key: .writableKeyPath(keyPath)) {
            Binding(
                get: { self[keyPath: keyPath] },
                set: { self[keyPath: keyPath] = $0 }
            )
        }
    }

    func binding<Value>(
        for keyPath: KeyPath<State, Value>,
        send: KeyPath<Model, (Value) -> Void>
    ) -> Binding<Value> {
        binding(key: .keyPathSend(keyPath: keyPath, sendPath: send)) {
            Binding(
                get: {
                    let val = self.state[keyPath: keyPath]
                    print("get \(keyPath) -> \(val)")
                    return val
                },
                set: {
                    print("set \(keyPath) <- \($0)")
                    self.model[keyPath: send]($0)
                }
            )
        }
    }

    func binding<Value, Action>(
        for keyPath: KeyPath<State, Value>,
        sink: KeyPath<Model, Sink<Action>>,
        action: CaseKeyPath<Action, Value>
    ) -> Binding<Value> {
        binding(key: .keyPathSinkAction(keyPath: keyPath, sinkPath: sink, actionPath: action)) {
            Binding(
                get: { self.state[keyPath: keyPath] },
                set: { self.model[keyPath: sink].send(action($0)) }
            )
        }
    }

    private func binding<Value>(key: BindingKey, create: () -> Binding<Value>) -> Binding<Value> {
        if let binding = bindings[key] as? Binding<Value> {
            print("cached binding for \(key)")
            _ = binding.wrappedValue
            return binding
        }

        print("new binding for \(key)")
        let binding = create()
        bindings[key] = binding

        return binding
    }

    enum BindingKey: Hashable {
        case writableKeyPath(AnyKeyPath)
        case keyPathSend(keyPath: AnyKeyPath, sendPath: AnyKeyPath)
        case keyPathSinkAction(keyPath: AnyKeyPath, sinkPath: AnyKeyPath, actionPath: AnyKeyPath)
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

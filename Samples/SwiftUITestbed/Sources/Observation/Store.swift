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

    subscript<Value>(
        state keyPath: KeyPath<State, Value>,
        action: CaseKeyPath<Action, Value>
    ) -> Value {
        get { self.state[keyPath: keyPath] }
        set { self.send(action(newValue)) }
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

    subscript<Value>(
        state state: KeyPath<State, Value>,
        send send: KeyPath<Model, (Value) -> Void>
    ) -> Value {
        get {
            let val = self.state[keyPath: state]
            print("get \(state) -> \(val)")
            return val
        }
        set {
            print("set \(state) <- \(newValue)")
            self.model[keyPath: send](newValue)
        }
    }

    subscript<Value, Action>(
        state state: KeyPath<State, Value>,
        sink sink: KeyPath<Model, Sink<Action>>,
        action action: CaseKeyPath<Action, Value>
    ) -> Value {
        get {
            self.state[keyPath: state]
        }
        set {
            self.model[keyPath: sink].send(action(newValue))
        }
    }

    enum BindingKey: Hashable {
        case writableKeyPath(AnyKeyPath)
        case keyPathSend(keyPath: AnyKeyPath, sendPath: AnyKeyPath)
        case keyPathSinkAction(keyPath: AnyKeyPath, sinkPath: AnyKeyPath, actionPath: AnyKeyPath)
    }

    func binding<Value>(for keyPath: ReferenceWritableKeyPath<Store<Model>, Value>) -> Binding<Value> {
        let key = BindingKey.writableKeyPath(keyPath)
        if let binding = bindings[key] as? Binding<Value> {
//            print("Reusing binding")// for \(keyPath)")
            _ = binding.wrappedValue
            return binding
        }

        // TODO: better to just do this in the setter?
        withPerceptionTracking {
            _ = self[keyPath: keyPath]
        } onChange: {
            print("invalidating binding")
            self.bindings[key] = nil
        }

        print("Creating binding")
        let binding = Binding<Value>(
            get: {
                let val = self[keyPath: keyPath]
                print("get -> \(val)")
                return val
            },
            set: {
                print("set <- \($0)")
                self[keyPath: keyPath] = $0
            }
        )
        bindings[key] = binding
        return binding
    }

    func clearBindings() {
        print("clearBindings")
        bindings.removeAll()
    }
}

extension Binding {
    @_disfavoredOverload
    subscript<Model: ObservableModel, Member>(
        dynamicMember keyPath: KeyPath<Model.State, Member>
    ) -> _StoreBinding<Model, Member>
    where Value == Store<Model>
    {
        print("Creating _StoreBindable for \(keyPath)")
        return _StoreBinding(binding: self, keyPath: keyPath)
    }
}

extension Perception.Bindable {
    @_disfavoredOverload
    subscript<Model: ObservableModel, Member>(
        dynamicMember keyPath: KeyPath<Model.State, Member>
    ) -> _StoreBindable<Model, Member>
    where Value == Store<Model>
    {
        print("Creating _StoreBindable for \(keyPath)")
        return _StoreBindable(bindable: self, keyPath: keyPath)
    }
}

@dynamicMemberLookup
struct _StoreBinding<Model: ObservableModel, Value> {
    fileprivate let binding: Binding<Store<Model>>
    fileprivate let keyPath: KeyPath<Model.State, Value>

    subscript<Member>(
        dynamicMember keyPath: KeyPath<Value, Member>
    ) -> _StoreBinding<Model, Member> {
        _StoreBinding<Model, Member>(
            binding: self.binding,
            keyPath: self.keyPath.appending(path: keyPath)
        )
    }

    /// Creates a binding to the value by sending new values through the given action.
    ///
    /// - Parameter action: An action for the binding to send values through.
    /// - Returns: A binding.
    public func sending<Action>(
        sink: KeyPath<Model, Sink<Action>>,
        action: CaseKeyPath<Action, Value>
    ) -> Binding<Value> {
        self.binding[state: keyPath, sink: sink, action: action]
    }
}

@dynamicMemberLookup
struct _StoreBindable<Model: ObservableModel, Value> {
    fileprivate let bindable: Perception.Bindable<Store<Model>>
    fileprivate let keyPath: KeyPath<Model.State, Value>

    subscript<Member>(
        dynamicMember keyPath: KeyPath<Value, Member>
    ) -> _StoreBindable<Model, Member> {
        _StoreBindable<Model, Member>(
            bindable: self.bindable,
            keyPath: self.keyPath.appending(path: keyPath)
        )
    }

    /// Creates a binding to the value by sending new values through the given action.
    ///
    /// - Parameter action: An action for the binding to send values through.
    /// - Returns: A binding.
    public func sending<Action>(
        sink: KeyPath<Model, Sink<Action>>,
        action: CaseKeyPath<Action, Value>
    ) -> Binding<Value> {
        print("Subscripting _StoreBindable for \(keyPath) sink + action")
        return self.bindable[state: keyPath, sink: sink, action: action]
    }

    public func sending(
        action: KeyPath<Model, (Value) -> Void>
    ) -> Binding<Value> {
        print("Subscripting _StoreBindable for closure action")
        return self.bindable[state: keyPath, send: action]
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

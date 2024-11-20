import CasePaths
import IdentifiedCollections
import Perception
import SwiftUI
import Workflow

/// Provides access to a workflow's state and actions from within an ``ObservableScreen``.
///
/// The store wraps an ``ObservableModel`` and provides controlled access to members through dynamic
/// member lookup:
/// - state properties
/// - action sinks
/// - child stores using nested `ObservableModel`s
///
/// Because arbitrary properties on the model cannot be tracked for observation, any other types of
/// properties will not be accessible.
///
/// For state properties that are writable, an automatic `Binding` can be derived by annotating the
/// store with `@Bindable`. These bindings will use the workflow's state mutation sink.
///
/// All properties can be turned into bindings by appending `sending(store:action:)` or
/// `sending(closure:)` to specify the "write" action. For properties that are already writable,
/// this will refine the binding to send a custom action instead of the built-in state mutation
/// sink.
///
@dynamicMemberLookup
public final class Store<Model: ObservableModel>: Perceptible {
    public typealias State = Model.State

    private var model: Model
    private let _$observationRegistrar = PerceptionRegistrar()

    private var childStores: [AnyHashable: ChildStore] = [:]
    private var childModelAccesses: [AnyHashable: ChildModelAccess] = [:]
    private var invalidated = false

    static func make(model: Model) -> (Store, (Model) -> Void) {
        let store = Store(model)
        return (store, store.setModel)
    }

    fileprivate init(_ model: Model) {
        self.model = model
    }

    var state: State {
        _$observationRegistrar.access(self, keyPath: \.state)
        return model.accessor.state
    }

    private func send<Value>(keyPath: WritableKeyPath<State, Value>, value: Value) {
        guard !invalidated else {
            return
        }
        model.accessor.sendValue { state in
            state[keyPath: keyPath] = value
        }
    }

    fileprivate func setModel(_ newModel: Model) {
        // Make a list of any child store accesses that are mutated as a result of this set. We'll
        // use this list to wrap the update with appropriate willSet/didSet calls.
        let changedChildAccess = childModelAccesses.values.filter { $0.isChanged(model, newModel) }

        /// Update the model, wrapped in willSet and didSet observations for mutations to child
        /// store wrappers.
        func updateModel() {
            for access in changedChildAccess {
                access.willSet(self)
            }

            model = newModel

            for access in changedChildAccess {
                access.didSet(self)
            }
        }

        // Update the model, registering a mutation if the state has changed

        if !_$isIdentityEqual(model.accessor.state, newModel.accessor.state) {
            _$observationRegistrar.withMutation(of: self, keyPath: \.state) {
                updateModel()
            }
        } else {
            updateModel()
        }

        // Update and invalidate child stores

        for (keyPath, childStore) in childStores {
            if childStore.isInvalid(newModel) {
                childStore.invalidate()
                childStores[keyPath] = nil
            } else {
                childStore.setModel(newModel)
            }
        }

        childModelAccesses = childModelAccesses.filter { _, access in
            !access.isInvalid(newModel)
        }
    }

    func invalidate() {
        invalidated = true
        for childStore in childStores.values {
            childStore.invalidate()
        }
    }
}

// MARK: - Subscripting

extension Store {
    public subscript<T>(dynamicMember keyPath: KeyPath<State, T>) -> T {
        state[keyPath: keyPath]
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<State, T>) -> T {
        get {
            state[keyPath: keyPath]
        }
        set {
            send(keyPath: keyPath, value: newValue)
        }
    }

    public subscript<Action>(dynamicMember keyPath: KeyPath<Model, Sink<Action>>) -> Sink<Action> {
        model[keyPath: keyPath]
    }

    public subscript<Value>(
        state state: KeyPath<State, Value>,
        send send: KeyPath<Model, (Value) -> Void>
    ) -> Value {
        get {
            self.state[keyPath: state]
        }
        set {
            model[keyPath: send](newValue)
        }
    }

    public subscript<Value, Action>(
        state state: KeyPath<State, Value>,
        sink sink: KeyPath<Model, Sink<Action>>,
        action action: CaseKeyPath<Action, Value>
    ) -> Value {
        get {
            self.state[keyPath: state]
        }
        set {
            model[keyPath: sink].send(action(newValue))
        }
    }
}

// MARK: - Scoping

extension Store {
    /// Holds a cached child store for a nested ObservableModel on this store's model.
    struct ChildStore {
        var store: Any
        var setModel: (Model) -> Void
        var isInvalid: (Model) -> Bool

        private var _invalidate: () -> Void

        init(
            store: Store<some ObservableModel>,
            setModel: @escaping (Model) -> Void,
            isInvalid: @escaping (Model) -> Bool
        ) {
            self.store = store
            self.setModel = setModel
            self.isInvalid = isInvalid

            self._invalidate = {
                store.invalidate()
            }
        }

        func invalidate() {
            _invalidate()
        }
    }

    /// Represents an access to the "wrapper" of a nested child store, such as an Optional or
    /// collection type.
    ///
    /// Each nested model's scope will track its own mutations, but we use this to track mutations
    /// to the wrapper itself, such as changes to a collection size.
    struct ChildModelAccess {
        var willSet: (Store<Model>) -> Void
        var didSet: (Store<Model>) -> Void
        var isChanged: (Model, Model) -> Bool
        var isInvalid: (Model) -> Bool

        init(
            keyPath: KeyPath<Model, some Any>,
            isChanged: @escaping (Model, Model) -> Bool,
            isInvalid: @escaping (Model) -> Bool
        ) {
            self.willSet = { store in
                store._$observationRegistrar.willSet(store, keyPath: (\Store.model).appending(path: keyPath))
            }
            self.didSet = { store in
                store._$observationRegistrar.didSet(store, keyPath: (\Store.model).appending(path: keyPath))
            }
            self.isChanged = isChanged
            self.isInvalid = isInvalid
        }
    }

    /// Track access to a child store wrapper.
    func access(
        keyPath key: KeyPath<Model, some Any>,
        isChanged: @escaping (Model, Model) -> Bool,
        isInvalid: @escaping (Model) -> Bool = { _ in false }
    ) {
        _$observationRegistrar.access(self, keyPath: (\Store.model).appending(path: key))
        if childModelAccesses[key] == nil {
            childModelAccesses[key] = ChildModelAccess(
                keyPath: key,
                isChanged: isChanged,
                isInvalid: isInvalid
            )
        }
    }

    func scope<ChildModel>(
        key: AnyHashable,
        getModel: @escaping (Model) -> ChildModel,
        isInvalid: @escaping (Model) -> Bool
    ) -> Store<ChildModel> {
        if let childStore = childStores[key]?.store as? Store<ChildModel> {
            return childStore
        }

        let childModel = getModel(model)
        let childStore = Store<ChildModel>(childModel)

        childStores[key] = ChildStore(
            store: childStore,
            setModel: { model in
                childStore.setModel(getModel(model))
            },
            isInvalid: isInvalid
        )

        return childStore
    }

    // Normal props

    public func scope<ChildModel>(keyPath: KeyPath<Model, ChildModel>) -> Store<ChildModel> {
        scope(
            key: keyPath,
            getModel: { $0[keyPath: keyPath] },
            isInvalid: { _ in false }
        )
    }

    // Optionals

    public func scope<ChildModel>(
        keyPath: KeyPath<Model, ChildModel?>
    ) -> Store<ChildModel>? {
        access(keyPath: keyPath) { oldModel, newModel in
            // invalidate if presence changes
            (oldModel[keyPath: keyPath] == nil) != (newModel[keyPath: keyPath] == nil)
        }

        guard let childModel = model[keyPath: keyPath] else {
            return nil
        }

        return scope(
            key: keyPath,
            getModel: { model in
                model[keyPath: keyPath] ?? childModel
            },
            isInvalid: { model in
                model[keyPath: keyPath] == nil
            }
        )
    }

    // Collections

    public func scope<ChildModel, ChildCollection>(
        collection: KeyPath<Model, ChildCollection>
    ) -> _StoreCollection<ChildModel>
        where
        ChildModel: ObservableModel,
        ChildCollection: RandomAccessCollection,
        ChildCollection.Element == ChildModel,
        ChildCollection.Index == Int
    {
        access(keyPath: collection) { oldModel, newModel in
            // invalidate if collection size changes
            oldModel[keyPath: collection].count != newModel[keyPath: collection].count
        }

        let models = model[keyPath: collection]

        return _StoreCollection(
            startIndex: models.startIndex,
            endIndex: models.endIndex
        ) { index in
            self.scope(
                key: collection.appending(path: \.[_offset: index]),
                getModel: { model in
                    model[keyPath: collection][index]
                },
                isInvalid: { model in
                    !model[keyPath: collection].indices.contains(index)
                }
            )
        }
    }

    public func scope<ChildModel>(
        collection: KeyPath<Model, IdentifiedArray<some Any, ChildModel>>
    ) -> _StoreCollection<ChildModel> where ChildModel: ObservableModel {
        access(keyPath: collection) { oldModel, newModel in
            // invalidate if collection size changes
            oldModel[keyPath: collection].count != newModel[keyPath: collection].count
        }

        let models = model[keyPath: collection]

        return _StoreCollection(
            startIndex: models.startIndex,
            endIndex: models.endIndex
        ) { index in
            let id = models.ids[index]

            // These scopes are keyed by ID and will not be invalidated by reordering. Register a
            // mutation to this index if its identity changes
            self.access(keyPath: collection.appending(path: \.[index])) { _, newModel in
                let newCollection = newModel[keyPath: collection]
                return !newCollection.indices.contains(index) || newCollection.ids[index] != id
            } isInvalid: { model in
                !model[keyPath: collection].ids.contains(id)
            }

            return self.scope(
                key: collection.appending(path: \.[id: id]),
                getModel: { model in
                    let models = model[keyPath: collection]
                    return models[id: id] ?? models[index]
                },
                isInvalid: { model in
                    !model[keyPath: collection].ids.contains(id)
                }
            )
        }
    }

    public subscript<ChildModel: ObservableModel>(dynamicMember keyPath: KeyPath<Model, ChildModel>) -> Store<ChildModel> {
        scope(keyPath: keyPath)
    }

    public subscript<ChildModel>(
        dynamicMember keyPath: KeyPath<Model, ChildModel?>
    ) -> Store<ChildModel>? {
        scope(keyPath: keyPath)
    }

    public subscript<ChildModel, ChildCollection>(
        dynamicMember collection: KeyPath<Model, ChildCollection>
    ) -> _StoreCollection<ChildModel> where
        ChildModel: ObservableModel,
        ChildCollection: RandomAccessCollection,
        ChildCollection.Element == ChildModel,
        ChildCollection.Index == Int
    {
        scope(collection: collection)
    }

    public subscript<ChildModel>(
        dynamicMember collection: KeyPath<Model, IdentifiedArray<some Any, ChildModel>>
    ) -> _StoreCollection<ChildModel> where ChildModel: ObservableModel {
        scope(collection: collection)
    }
}

// NB: Would prefer to return `some RandomAccessCollection` and make this internal, but in Xcode
// 15.1 it breaks subscript access: "Missing argument label '_offset:' in subscript". Revisit later.

public struct _StoreCollection<Model: ObservableModel>: RandomAccessCollection {
    init(startIndex: Int, endIndex: Int, storeAtIndex: @escaping (Int) -> Store<Model>) {
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.storeAtIndex = storeAtIndex
    }

    public let startIndex: Int
    public let endIndex: Int
    private let storeAtIndex: (Int) -> Store<Model>

    public subscript(position: Int) -> Store<Model> {
        storeAtIndex(position)
    }
}

// MARK: - Single action conveniences

extension Store where Model: SingleActionModel {
    public func action(_ action: Model.Action) -> () -> Void {
        { self.send(action) }
    }

    public func send(_ action: Model.Action) {
        guard !invalidated else {
            return
        }
        model.sendAction(action)
    }

    public subscript<Value>(
        state keyPath: KeyPath<State, Value>,
        action action: CaseKeyPath<Model.Action, Value>
    ) -> Value {
        get { state[keyPath: keyPath] }
        set { send(action(newValue)) }
    }
}

// MARK: - Conformances

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

import CasePaths
import IdentifiedCollections
import Perception
import SwiftUI
import Workflow
import XCTest
@testable import WorkflowSwiftUI

final class StoreTests: XCTestCase {
    func test_stateRead() {
        var state = State()
        let model = StateAccessor(state: state) { update in
            update(&state)
        }
        let (store, _) = Store.make(model: model)

        withPerceptionTracking {
            XCTAssertEqual(store.count, 0)
        } onChange: {
            XCTFail("State should not have been mutated")
        }
    }

    func test_stateMutation() async {
        var state = State()
        let model = StateAccessor(state: state) { update in
            update(&state)
        }
        let (store, _) = Store.make(model: model)

        let countDidChange = expectation(description: "count.didChange")

        withPerceptionTracking {
            _ = store.count
        } onChange: {
            countDidChange.fulfill()
        }

        withPerceptionTracking {
            _ = store.child.name
        } onChange: {
            XCTFail("child.name should not change")
        }

        store.count = 1
        await fulfillment(of: [countDidChange], timeout: 0)
        XCTAssertEqual(state.count, 1)
    }

    func test_childStateMutation() async {
        var state = State()
        let model = StateAccessor(state: state) { update in
            update(&state)
        }
        let (store, _) = Store.make(model: model)

        let childNameDidChange = expectation(description: "child.name.didChange")

        withPerceptionTracking {
            _ = store.count
        } onChange: {
            XCTFail("count should not change")
        }

        withPerceptionTracking {
            _ = store.child.name
        } onChange: {
            childNameDidChange.fulfill()
        }

        store.child.name = "foo"
        await fulfillment(of: [childNameDidChange], timeout: 0)
        XCTAssertEqual(state.count, 0)
        XCTAssertEqual(state.child.name, "foo")
    }

    func test_stateReplacement() async {
        var state = State()
        let model = StateAccessor(state: state) { update in
            update(&state)
        }
        let (store, setModel) = Store.make(model: model)

        let countDidChange = expectation(description: "count.didChange")

        withPerceptionTracking {
            _ = store.count
        } onChange: {
            countDidChange.fulfill()
        }

        var newState = State(count: 1)
        let newModel = StateAccessor(state: newState) { update in
            update(&newState)
        }

        setModel(newModel)

        await fulfillment(of: [countDidChange], timeout: 0)
        XCTAssertEqual(state.count, 0)
        XCTAssertEqual(newState.count, 1)

        store.count = 2

        XCTAssertEqual(state.count, 0)
        XCTAssertEqual(newState.count, 2)
    }

    func test_sinkAccess() async {
        var state = State()
        let actionCalled = expectation(description: "action.called")
        let model = CustomActionModel(
            accessor: StateAccessor(state: state) { update in
                update(&state)
            },
            sink: Sink { _ in
                actionCalled.fulfill()
            }
        )
        let (store, _) = Store.make(model: model)

        store.sink.send(.foo)
        await fulfillment(of: [actionCalled], timeout: 0)
    }

    func test_stateWithSetterClosure() async {
        var state = State()
        let model = ClosureModel(
            accessor: StateAccessor(state: state) { _ in
                XCTFail("state should not be mutated through accessor")
            },
            onCountChanged: { count in
                state.count = count
            }
        )
        let (store, _) = Store.make(model: model)

        let countDidChange = expectation(description: "count.didChange")
        withPerceptionTracking {
            _ = store.count
        } onChange: {
            countDidChange.fulfill()
        }

        XCTAssertEqual(store[state: \.count, send: \.onCountChanged], 0)
        store[state: \.count, send: \.onCountChanged] = 1

        await fulfillment(of: [countDidChange], timeout: 0)
        XCTAssertEqual(state.count, 1)
    }

    func test_stateWithSetterAction() async {
        var state = State()
        let model = CustomActionModel(
            accessor: StateAccessor(state: state) { _ in
                XCTFail("state should not be mutated through accessor")
            },
            sink: Sink { action in
                switch action {
                case .onCountChanged(let count):
                    state.count = count
                case .foo:
                    XCTFail("unexpected action: \(action)")
                }
            }
        )
        let (store, _) = Store.make(model: model)

        let countDidChange = expectation(description: "count.didChange")
        withPerceptionTracking {
            _ = store.count
        } onChange: {
            countDidChange.fulfill()
        }

        XCTAssertEqual(store[state: \.count, sink: \.sink, action: \.onCountChanged], 0)
        store[state: \.count, sink: \.sink, action: \.onCountChanged] = 1

        await fulfillment(of: [countDidChange], timeout: 0)
        XCTAssertEqual(state.count, 1)
    }

    func test_singleActionModel() async {
        func makeModel(state: State, sink: Sink<Action>) -> ActionModel<State, Action> {
            ActionModel(
                accessor: StateAccessor(state: state) { _ in
                    XCTFail("state should not be mutated through accessor")
                },
                sendAction: sink.send
            )
        }

        // store.send
        do {
            var state = State()
            let sink = Sink<Action> { action in
                switch action {
                case .onCountChanged(let count):
                    state.count = count
                case .foo:
                    XCTFail("unexpected action: \(action)")
                }
            }
            let model = makeModel(state: state, sink: sink)
            let (store, _) = Store.make(model: model)

            let countDidChange = expectation(description: "count.didChange")
            withPerceptionTracking {
                _ = store.count
            } onChange: {
                countDidChange.fulfill()
            }

            store.send(.onCountChanged(1))
            await fulfillment(of: [countDidChange], timeout: 0)
            XCTAssertEqual(state.count, 1)
        }

        // store.action
        do {
            var state = State()
            let sink = Sink<Action> { action in
                switch action {
                case .onCountChanged(let count):
                    state.count = count
                case .foo:
                    XCTFail("unexpected action: \(action)")
                }
            }
            let model = makeModel(state: state, sink: sink)
            let (store, _) = Store.make(model: model)

            let countDidChange = expectation(description: "count.didChange")
            withPerceptionTracking {
                _ = store.count
            } onChange: {
                countDidChange.fulfill()
            }

            let action = store.action(.onCountChanged(2))
            XCTAssertEqual(state.count, 0)

            action()
            await fulfillment(of: [countDidChange], timeout: 0)
            XCTAssertEqual(state.count, 2)
        }

        // store[state:action:]
        do {
            var state = State()
            let sink = Sink<Action> { action in
                switch action {
                case .onCountChanged(let count):
                    state.count = count
                case .foo:
                    XCTFail("unexpected action: \(action)")
                }
            }
            let model = makeModel(state: state, sink: sink)
            let (store, _) = Store.make(model: model)

            let countDidChange = expectation(description: "count.didChange")
            withPerceptionTracking {
                _ = store.count
            } onChange: {
                countDidChange.fulfill()
            }

            store[state: \State.count, action: \.onCountChanged] = 3

            await fulfillment(of: [countDidChange], timeout: 0)
            XCTAssertEqual(state.count, 3)
        }
    }

    // MARK: - Child stores

    func test_childStore() async {
        var childState = ParentModel.ChildState(age: 0)

        let model = ParentModel(
            accessor: StateAccessor(state: State()) { _ in
                XCTFail("parent state should not be mutated")
            },
            child: StateAccessor(state: childState) { update in
                update(&childState)
            },
            array: [],
            identified: []
        )
        let (store, _) = Store.make(model: model)

        let childAgeDidChange = expectation(description: "child.age.didChange")
        withPerceptionTracking {
            _ = store.child.age
        } onChange: {
            childAgeDidChange.fulfill()
        }

        store.child.age = 1

        await fulfillment(of: [childAgeDidChange], timeout: 0)
        XCTAssertEqual(childState.age, 1)
    }

    func test_childStore_optional() async {
        func makeModel() -> ParentModel {
            ParentModel(
                accessor: StateAccessor(state: State()) { _ in
                    XCTFail("parent state should not be mutated")
                },
                child: StateAccessor(state: .init()) { _ in
                    XCTFail("child state should not be mutated")
                },
                array: [],
                identified: []
            )
        }

        // some to nil
        do {
            var childState = ParentModel.ChildState(age: 0)
            let childModel = StateAccessor(state: childState) { update in
                update(&childState)
            }
            var model = makeModel()
            let (store, setModel) = Store.make(model: model)

            model.optional = childModel
            setModel(model)

            let optionalDidChange = expectation(description: "optional.didChange")
            withPerceptionTracking {
                _ = store.optional
            } onChange: {
                optionalDidChange.fulfill()
            }

            model.optional = nil
            setModel(model)

            await fulfillment(of: [optionalDidChange], timeout: 0)
        }

        // nil to some
        do {
            var childState = ParentModel.ChildState(age: 0)
            let childModel = StateAccessor(state: childState) { update in
                update(&childState)
            }
            var model = makeModel()
            let (store, setModel) = Store.make(model: model)

            model.optional = nil
            setModel(model)

            let optionalDidChange = expectation(description: "optional.didChange")
            withPerceptionTracking {
                _ = store.optional
            } onChange: {
                optionalDidChange.fulfill()
            }

            model.optional = childModel
            setModel(model)

            await fulfillment(of: [optionalDidChange], timeout: 0)
        }

        // some to some
        do {
            var childState = ParentModel.ChildState(age: 0)
            let childModel = StateAccessor(state: childState) { update in
                update(&childState)
            }
            var model = makeModel()
            let (store, setModel) = Store.make(model: model)

            model.optional = childModel
            setModel(model)

            withPerceptionTracking {
                _ = store.optional
            } onChange: {
                XCTFail("optional should not change")
            }

            let optionalAgeDidChange = expectation(description: "optional.age.didChange")
            withPerceptionTracking {
                _ = store.optional?.age
            } onChange: {
                optionalAgeDidChange.fulfill()
            }

            // the new instance will trigger a change in store.optional.age even though the value
            // does not change
            var newChildState = ParentModel.ChildState(age: 0)
            let newChildModel = StateAccessor(state: newChildState) { update in
                update(&newChildState)
            }

            model.optional = newChildModel
            setModel(model)

            await fulfillment(of: [optionalAgeDidChange], timeout: 0)
        }

        // nil to nil
        do {
            var model = makeModel()
            let (store, setModel) = Store.make(model: model)

            model.optional = nil
            setModel(model)

            withPerceptionTracking {
                _ = store.optional
            } onChange: {
                XCTFail("optional should not change")
            }

            model.optional = nil
            setModel(model)
        }
    }

    func test_childStore_collection() async {
        func makeChildStates() -> [ParentModel.ChildState] {
            [
                .init(age: 0),
                .init(age: 1),
                .init(age: 2),
            ]
        }

        func makeChildModels(childStates: [ParentModel.ChildState]) -> [StateAccessor<ParentModel.ChildState>] {
            childStates.map { state in
                StateAccessor(state: state) { _ in
                    XCTFail("child state should not be mutated")
                }
            }
        }

        func makeModel() -> ParentModel {
            ParentModel(
                accessor: StateAccessor(state: State()) { _ in
                    XCTFail("parent state should not be mutated")
                },
                child: StateAccessor(state: .init()) { _ in
                    XCTFail("child state should not be mutated")
                },
                array: [],
                identified: []
            )
        }

        // add
        do {
            let childStates = makeChildStates()
            let childModels = makeChildModels(childStates: childStates)
            var model = makeModel()
            let (store, setModel) = Store.make(model: model)

            model.array = []
            setModel(model)

            let arrayDidChange = expectation(description: "array.didChange")
            withPerceptionTracking {
                _ = store.array
            } onChange: {
                arrayDidChange.fulfill()
            }

            model.array = childModels
            setModel(model)

            await fulfillment(of: [arrayDidChange], timeout: 0)
        }

        // remove
        do {
            let childStates = makeChildStates()
            let childModels = makeChildModels(childStates: childStates)
            var model = makeModel()
            let (store, setModel) = Store.make(model: model)

            model.array = childModels
            setModel(model)

            let arrayDidChange = expectation(description: "array.didChange")
            withPerceptionTracking {
                _ = store.array
            } onChange: {
                arrayDidChange.fulfill()
            }

            model.array = []
            setModel(model)

            await fulfillment(of: [arrayDidChange], timeout: 0)
        }

        // reorder
        do {
            let childStates = makeChildStates()
            let childModels = makeChildModels(childStates: childStates)
            var model = makeModel()
            let (store, setModel) = Store.make(model: model)

            model.array = childModels
            setModel(model)

            withPerceptionTracking {
                _ = store.array
            } onChange: {
                XCTFail("array should not change")
            }

            let array0AgeDidChange = expectation(description: "array[0].age.didChange")
            withPerceptionTracking {
                _ = store.array[0].age
            } onChange: {
                array0AgeDidChange.fulfill()
            }

            model.array = [childModels[1], childModels[2], childModels[0]]
            setModel(model)

            await fulfillment(of: [array0AgeDidChange], timeout: 0)
        }
    }

    func test_childStore_identifiedCollection() async {
        func makeChildStates() -> [ParentModel.ChildState] {
            [
                .init(age: 0),
                .init(age: 1),
                .init(age: 2),
            ]
        }

        func makeModel() -> ParentModel {
            ParentModel(
                accessor: StateAccessor(state: State()) { _ in
                    XCTFail("parent state should not be mutated")
                },
                child: StateAccessor(state: .init()) { _ in
                    XCTFail("child state should not be mutated")
                },
                array: [],
                identified: []
            )
        }

        // add
        do {
            var childStates = makeChildStates()
            let childModels = IdentifiedArray(
                uniqueElements: zip(childStates.indices, childStates).map { index, state in
                    StateAccessor(state: state) { update in
                        update(&childStates[index])
                    }
                }
            )
            var model = makeModel()
            let (store, setModel) = Store.make(model: model)

            model.identified = []
            setModel(model)

            let identifiedDidChange = expectation(description: "identified.didChange")
            withPerceptionTracking {
                _ = store.identified
            } onChange: {
                identifiedDidChange.fulfill()
            }

            model.identified = childModels
            setModel(model)

            await fulfillment(of: [identifiedDidChange], timeout: 0)
        }

        // remove
        do {
            var childStates = makeChildStates()
            let childModels = IdentifiedArray(
                uniqueElements: zip(childStates.indices, childStates).map { index, state in
                    StateAccessor(state: state) { update in
                        update(&childStates[index])
                    }
                }
            )
            var model = makeModel()
            let (store, setModel) = Store.make(model: model)

            model.identified = childModels
            setModel(model)

            let arrayDidChange = expectation(description: "identified.didChange")
            withPerceptionTracking {
                _ = store.identified
            } onChange: {
                arrayDidChange.fulfill()
            }

            model.identified = []
            setModel(model)

            await fulfillment(of: [arrayDidChange], timeout: 0)
        }

        // reorder
        do {
            var childStates = makeChildStates()
            let childModels = IdentifiedArray(
                uniqueElements: zip(childStates.indices, childStates).map { index, state in
                    StateAccessor(state: state) { update in
                        update(&childStates[index])
                    }
                }
            )
            var model = makeModel()
            let (store, setModel) = Store.make(model: model)

            model.identified = childModels
            setModel(model)

            withPerceptionTracking {
                _ = store.identified
            } onChange: {
                XCTFail("identified should not change")
            }

            let identified0AgeDidChange = expectation(description: "identified[0].age.didChange")
            withPerceptionTracking {
                _ = store.identified[0].age
            } onChange: {
                identified0AgeDidChange.fulfill()
            }

            model.identified = [childModels[1], childModels[2], childModels[0]]
            setModel(model)

            await fulfillment(of: [identified0AgeDidChange], timeout: 0)
        }
    }

    func test_invalidation() {
        // TODO:
    }

    // MARK: - Bindings

    @MainActor
    func test_bindings() async {
        var state = State()
        let model = StateAccessor(state: state) { update in
            update(&state)
        }
        let (_store, _) = Store.make(model: model)
        @Perception.Bindable var store = _store

        let countDidChange = expectation(description: "count.didChange")

        withPerceptionTracking {
            _ = store.count
        } onChange: {
            countDidChange.fulfill()
        }

        let binding = $store.count
        binding.wrappedValue = 1

        await fulfillment(of: [countDidChange], timeout: 0)
        XCTAssertEqual(state.count, 1)
    }

    @MainActor
    func test_bindingSendingCustomAction() async {
        var state = State()
        let model = CustomActionModel(
            accessor: StateAccessor(state: state) { _ in
                XCTFail("state should not be mutated through accessor")
            },
            sink: Sink { action in
                switch action {
                case .onCountChanged(let count):
                    state.count = count
                case .foo:
                    XCTFail("unexpected action: \(action)")
                }
            }
        )
        let (_store, _) = Store.make(model: model)
        @Perception.Bindable var store = _store

        let countDidChange = expectation(description: "count.didChange")

        withPerceptionTracking {
            _ = store.count
        } onChange: {
            countDidChange.fulfill()
        }

        let binding = $store.count.sending(sink: \.sink, action: \.onCountChanged)
        binding.wrappedValue = 1

        await fulfillment(of: [countDidChange], timeout: 0)
        XCTAssertEqual(state.count, 1)
    }

    @MainActor
    func test_bindingSendingClosure() async {
        var state = State()
        let model = ClosureModel(
            accessor: StateAccessor(state: state) { _ in
                XCTFail("state should not be mutated through accessor")
            },
            onCountChanged: { count in
                state.count = count
            }
        )
        let (_store, _) = Store.make(model: model)
        @Perception.Bindable var store = _store

        let countDidChange = expectation(description: "count.didChange")

        withPerceptionTracking {
            _ = store.count
        } onChange: {
            countDidChange.fulfill()
        }

        let binding = $store.count.sending(closure: \.onCountChanged)
        binding.wrappedValue = 1

        await fulfillment(of: [countDidChange], timeout: 0)
        XCTAssertEqual(state.count, 1)
    }

    @MainActor
    func test_bindingSendingSingleAction() async {
        var state = State()
        let model = ActionModel(
            accessor: StateAccessor(state: state) { _ in
                XCTFail("state should not be mutated through accessor")
            },
            sendAction: Sink<Action> { action in
                switch action {
                case .onCountChanged(let count):
                    state.count = count
                case .foo:
                    XCTFail("unexpected action: \(action)")
                }
            }.send
        )
        let (_store, _) = Store.make(model: model)
        @Perception.Bindable var store = _store

        let countDidChange = expectation(description: "count.didChange")

        withPerceptionTracking {
            _ = store.count
        } onChange: {
            countDidChange.fulfill()
        }

        let binding = $store.count.sending(action: \.onCountChanged)
        binding.wrappedValue = 1

        await fulfillment(of: [countDidChange], timeout: 0)
        XCTAssertEqual(state.count, 1)
    }
}

@ObservableState
private struct State {
    var count = 0
    var child = Child()

    @ObservableState
    struct Child {
        var name = ""
    }
}

@CasePathable
private enum Action {
    case foo
    case onCountChanged(Int)
}

private struct CustomActionModel: ObservableModel {
    var accessor: StateAccessor<State>

    var sink: Sink<Action>
}

private struct ClosureModel: ObservableModel {
    var accessor: StateAccessor<State>

    var onCountChanged: (Int) -> Void
}

private struct ParentModel: ObservableModel {
    @ObservableState
    struct ChildState: Identifiable {
        let id = UUID()
        var age = 0
    }

    typealias ChildModel = StateAccessor<ChildState>

    var accessor: StateAccessor<State>

    var child: ChildModel
    var optional: ChildModel?
    var array: [ChildModel] = []
    var identified: IdentifiedArrayOf<ChildModel> = []
}

// MARK: -

// @testable import WorkflowTesting

@ObservableState
struct MyObsState {
    var obsProp1 = 0
    var obsProp2 = "two"
}

final class BlahTests: XCTestCase {
    @available(iOS 17.0, *)
    func test_zz() {
        let a = MyAction.one

        let wf = MyWF()

        let mgdState = Managed<MyWF>(
            wf.makeInitialState(),
            props: wf
        )

//        withObservationTracking {
        withPerceptionTracking {
            wf.render2(state: mgdState)
        } onChange: {
            print("changed 1")
        }

//        let ctx = RenderTester<MyWF>.TestContext.init(
//            state: wf.makeInitialState(),
//            expectedWorkflows: [],
//            expectedSideEffects: [:],
//            file: #file,
//            line: #line
//        )

        let rez = withPerceptionTracking {
            a.apply(toState: mgdState)
        } onChange: {
            print("changed")
        }

//        let rez = a.apply(toState: mgdState)
        print(rez)
    }
}

// MARK: -

// @propertyWrapper
@dynamicMemberLookup
struct Managed<W: Workflow>
//: ~Copyable
{
    typealias State = W.State
    typealias Props = W

    final class Storage {
        var props: Props
        var state: State

        init(_ state: State, props: Props) {
            self.state = state
            self.props = props
        }
    }

    init(_ state: State, props: Props) {
        self.storage = .init(state, props: props)
    }

    private let storage: Storage

    subscript<Value>(
        dynamicMember keyPath: WritableKeyPath<W.State, Value>
    ) -> Value {
        get {
            print("getting state: \(keyPath)")
            return self.storage.state[keyPath: keyPath]
        }
//        nonmutating set {
//            print("setting state: \(keyPath)")
//            self.storage.state[keyPath: keyPath] = newValue
//        }
        nonmutating _modify {
            yield &self.storage.state[keyPath: keyPath]
        }
    }

    func readProps<R>(
        _ body: (Managed3<Props>) -> R
    ) -> R {
        let managed3 = Managed3<Props>(self.storage.props)
        return body(managed3)
    }

    subscript<Value>(
        dynamicMember keyPath: KeyPath<W, Value>
    ) -> Value {
        self.storage.props[keyPath: keyPath]
    }
}

@dynamicMemberLookup
struct Managed3<State> {
    final class Storage {
        var state: State

        init(state: State) {
            self.state = state
        }
    }

    private let storage: Storage

    init(_ state: State) {
        self.storage = .init(state: state)
    }

    subscript<StateValue>(
        dynamicMember keyPath: WritableKeyPath<State, StateValue>
    ) -> StateValue {
        get {
            self.storage.state[keyPath: keyPath]
        }
        nonmutating set {
            self.storage.state[keyPath: keyPath] = newValue
        }
    }
}

@dynamicMemberLookup
struct Managed2<State, Props> {
    final class Storage {
        var props: Props
        var state: State

        init(state: State, props: Props) {
            self.state = state
            self.props = props
        }
    }

    private let storage: Storage

    subscript<StateValue>(
        dynamicMember keyPath: WritableKeyPath<State, StateValue>
    ) -> StateValue {
        get {
            self.storage.state[keyPath: keyPath]
        }
        nonmutating set {
            self.storage.state[keyPath: keyPath] = newValue
        }
    }

    func withProperty<PropValue, R>(
        _ propKeyPath: KeyPath<Props, PropValue>,
        _ body: (PropValue) -> R
    ) -> R {
        body(self.storage.props[keyPath: propKeyPath])
    }

//    subscript<PropValue>(
//        dynamicMember keyPath: KeyPath<Props, PropValue>
//    ) -> PropValue {
//        self.storage.props[keyPath: keyPath]
//    }
}

// extension Managed where State: AnyObject {
//    subscript<Value>(
//        dynamicMember keyPath: ReferenceWritableKeyPath<State, Value>
//    ) -> Value {
//        get { self.storage.state[keyPath: keyPath] }
//        set { self.storage.state[keyPath: keyPath] = newValue }
//    }
// }

protocol WA {
    associatedtype WF: Workflow

    func apply(
        toState state: Managed<WF>
    ) -> WF.Output?
}

protocol DefaultConstructible {
    init()
}

extension DefaultConstructible {
    static func make() -> Self { Self() }
}

struct Blah {
    var one = 1
    var two = "hi"
}

extension Blah: DefaultConstructible {}

func g() {
    let x: DefaultConstructible = Blah()

    let y = Blah.make()
}

extension Workflow where State: DefaultConstructible {
    func makeInitialState() -> State { State.make() }
}

func escape(_ it: @escaping () -> Void) {}

struct MyWF: Workflow {
    func render(state: MyState, context: borrowing RenderContext<MyWF>) {}

//    func render(state: MyState, context: RenderContext<Self>) -> Void {
//    }

    func render2(
        state: Managed<Self>
//        context: RenderContext<Self>
    ) {
//        let s = state.readProps { $0 }
        _ = state.prop2
    }

    typealias Rendering = Void

    @ObservableState
    struct MyState {
        var prop1 = "hi"
        var prop2 = 0
    }

    var wfProp1 = "hola"
    var wfProp2 = 42

    func workflowDidChange(from previousWorkflow: MyWF, state: inout MyState) {}

    func workflowDidChange2(state: Managed<Self>) {
        state.readProps { props in
            props.wfProp1
        }
    }

    func makeInitialState() -> MyState {
        MyState()
    }
}

enum MyAction: WA {
    typealias WF = MyWF

    case one
    case two

    func apply(toState state: Managed<MyWF>) -> WF.Output? {
        switch self {
        case .one:
            state.prop2 = 1
        case .two:
            state.prop2 = 2
        }

        return nil
    }
}

// MARK: -

// public class RenderContext2<WorkflowType: Workflow>: RenderContextType2 {
//    private(set) var isValid = true
//
//    // Ensure that this class can never be initialized externally
//    private init() {}
//
//    /// Creates or updates a child workflow of the given type, performs a render
//    /// pass, and returns the result.
//    ///
//    /// Note that it is a programmer error to render two instances of a given workflow type with the same `key`
//    /// during the same render pass.
//    ///
//    /// - Parameter workflow: The child workflow to be rendered.
//    /// - Parameter outputMap: A closure that transforms the child's output type into `Action`.
//    /// - Parameter key: A string that uniquely identifies this child.
//    ///
//    /// - Returns: The `Rendering` result of the child's `render` method.
//    func render<Child, Action>(workflow: Child, key: String, outputMap: @escaping (Child.Output) -> Action) -> Child.Rendering where Child: Workflow, Action: WorkflowAction, WorkflowType == Action.WorkflowType {
//        fatalError()
//    }
//
//    /// Creates a `Sink` that can be used to send `Action`s.
//    ///
//    /// Sinks are the primary mechanism for feeding State-changing events into the Workflow runtime.
//    /// Upon receipt of an action, the associated Workflow (node) in the tree will have its State
//    /// potentially transformed, and then any subsequent Output will be propagated to its parent node until
//    /// the root of the Workflow tree is reached. At this point the tree will be re-rendered to reflect any
//    /// State changes that occurred.
//    ///
//    /// - Parameter actionType: The type of Action this Sink may process
//    /// - Returns: A Sink capable of relaying `Action` instances to the Workflow runtime
//    public func makeSink<Action>(of actionType: Action.Type) -> Sink<Action> where Action: WorkflowAction, Action.WorkflowType == WorkflowType {
//        fatalError()
//    }
//
//    /// Execute a side-effect action.
//    ///
//    /// Note that it is a programmer error to run two side-effects with the same `key`
//    /// during the same render pass.
//    ///
//    /// `action` will be executed the first time a side-effect is run with a given `key`.
//    /// `runSideEffect` calls with a given `key` on subsequent renders are ignored.
//    ///
//    /// If after a render pass, a side-effect with a `key` that was previously used is not used,
//    /// it's lifetime ends and the `Lifetime` object's `onEnded` closure will be called.
//    ///
//    /// - Parameters:
//    ///   - key: represents the block of work that needs to be executed.
//    ///   - action: a block of work that will be executed.
//    public func runSideEffect(key: AnyHashable, action: (Lifetime) -> Void) {
//        fatalError()
//    }
//
//    final func invalidate() {
//        isValid = false
//    }
//
//    // API to allow custom context implementations to power a render context
//    static func make<T: RenderContextType2>(
//        implementation: T
//    ) -> RenderContext<WorkflowType>
//    where T.WorkflowType == WorkflowType
//    {
//        ConcreteRenderContext(implementation)
//    }
//
//    // Private subclass that forwards render calls to a wrapped implementation. This is the only `RenderContext` class
//    // that is ever instantiated.
//    private struct ConcreteRenderContext2<T: RenderContextType2>: RenderContext where WorkflowType == T.WorkflowType {
//        let implementation: T
//
//        init(_ implementation: T) {
//            self.implementation = implementation
//            super.init()
//        }
//
//        override func render<Child, Action>(workflow: Child, key: String, outputMap: @escaping (Child.Output) -> Action) -> Child.Rendering where WorkflowType == Action.WorkflowType, Child: Workflow, Action: WorkflowAction {
//            assertStillValid()
//            return implementation.render(workflow: workflow, key: key, outputMap: outputMap)
//        }
//
//        override func makeSink<Action>(of actionType: Action.Type) -> Sink<Action> where WorkflowType == Action.WorkflowType, Action: WorkflowAction {
//            assertStillValid()
//            return implementation.makeSink(of: actionType)
//        }
//
//        override func runSideEffect(key: AnyHashable, action: (_ lifetime: Lifetime) -> Void) {
//            assertStillValid()
//            implementation.runSideEffect(key: key, action: action)
//        }
//
//        private func assertStillValid() {
//            assert(isValid, "A `RenderContext` instance was used outside of the workflow's `render` method. It is a programmer error to capture a context in a closure or otherwise cause it to be used outside of the `render` method.")
//        }
//    }
// }
//
// struct RenderContextImpl<Child, Action>: ~Copyable {
////    var renderChild: (
// }
//
// protocol RenderContextType2: ~Copyable {
//    associatedtype WorkflowType: Workflow
//
//    func render<Child: Workflow, Action: WorkflowAction>(
//        workflow: Child,
//        key: String,
//        outputMap: @escaping (Child.Output) -> Action
//    ) -> Child.Rendering where Action.WorkflowType == WorkflowType
//
//    func makeSink<Action>(
//        of actionType: Action.Type
//    ) -> Sink<Action> where Action: WorkflowAction, Action.WorkflowType == WorkflowType
//
//    func runSideEffect(
//        key: AnyHashable,
//        action: (_ lifetime: Lifetime) -> Void
//    )
// }

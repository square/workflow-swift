// import CasePaths
// import IdentifiedCollections
// import Perception
// import SwiftUI
// import Workflow
// import WorkflowMacrosSupport
// import XCTest
// @testable import WorkflowSwiftUI
//
// @ObservableState
// struct FooState {
//    var count = 0
// }
//
// final class StoreTests: XCTestCase {
//    func test_perceiveWrites() {
//        var state = FooState()
//        let model = StateAccessor(state: state) { update in
//            update(&state)
//        }
//        let (store, _) = Store.make(model: model)
//
//        withPerceptionTracking {
//            _ = store.state
//        } onChange: {
//            print("onChange called")
//        }
//
//        state.count += 1
//        print("done")
//    }
//
//    func test_stateRead() {
//        var state = State()
//        let model = StateAccessor(state: state) { update in
//            update(&state)
//        }
//        let (store, _) = Store.make(model: model)
//
//        withPerceptionTracking {
//            XCTAssertEqual(store.count, 0)
//        } onChange: {
//            XCTFail("State should not have been mutated")
//        }
//    }
//
//    func test_stateMutation() async {
//        var state = State()
//        let model = StateAccessor(state: state) { update in
//            update(&state)
//        }
//        let (store, _) = Store.make(model: model)
//
//        let countDidChange = expectation(description: "count.didChange")
//
//        withPerceptionTracking {
//            _ = store.count
//        } onChange: {
//            countDidChange.fulfill()
//        }
//
//        withPerceptionTracking {
//            _ = store.child.name
//        } onChange: {
//            XCTFail("child.name should not change")
//        }
//
//        store.count = 1
//        await fulfillment(of: [countDidChange], timeout: 0)
//        XCTAssertEqual(state.count, 1)
//    }
//
//    func test_childStateMutation() async {
//        var state = State()
//        let model = StateAccessor(state: state) { update in
//            update(&state)
//        }
//        let (store, _) = Store.make(model: model)
//
//        let childNameDidChange = expectation(description: "child.name.didChange")
//
//        withPerceptionTracking {
//            _ = store.count
//        } onChange: {
//            XCTFail("count should not change")
//        }
//
//        withPerceptionTracking {
//            _ = store.child.name
//        } onChange: {
//            childNameDidChange.fulfill()
//        }
//
//        store.child.name = "foo"
//        await fulfillment(of: [childNameDidChange], timeout: 0)
//        XCTAssertEqual(state.count, 0)
//        XCTAssertEqual(state.child.name, "foo")
//    }
//
//    func test_stateReplacement() async {
//        var state = State()
//        let model = StateAccessor(state: state) { update in
//            update(&state)
//        }
//        let (store, setModel) = Store.make(model: model)
//
//        let countDidChange = expectation(description: "count.didChange")
//
//        withPerceptionTracking {
//            _ = store.count
//        } onChange: {
//            countDidChange.fulfill()
//        }
//
//        var newState = State(count: 1)
//        let newModel = StateAccessor(state: newState) { update in
//            update(&newState)
//        }
//
//        setModel(newModel)
//
//        await fulfillment(of: [countDidChange], timeout: 0)
//        XCTAssertEqual(state.count, 0)
//        XCTAssertEqual(newState.count, 1)
//
//        store.count = 2
//
//        XCTAssertEqual(state.count, 0)
//        XCTAssertEqual(newState.count, 2)
//    }
//
//    func test_sinkAccess() async {
//        var state = State()
//        let actionCalled = expectation(description: "action.called")
//        let model = CustomActionModel(
//            accessor: StateAccessor(state: state) { update in
//                update(&state)
//            },
//            sink: Sink { _ in
//                actionCalled.fulfill()
//            }
//        )
//        let (store, _) = Store.make(model: model)
//
//        store.sink.send(.foo)
//        await fulfillment(of: [actionCalled], timeout: 0)
//    }
//
//    func test_stateWithSetterClosure() async {
//        var state = State()
//        let model = ClosureModel(
//            accessor: StateAccessor(state: state) { _ in
//                XCTFail("state should not be mutated through accessor")
//            },
//            onCountChanged: { count in
//                state.count = count
//            }
//        )
//        let (store, _) = Store.make(model: model)
//
//        let countDidChange = expectation(description: "count.didChange")
//        withPerceptionTracking {
//            _ = store.count
//        } onChange: {
//            countDidChange.fulfill()
//        }
//
//        XCTAssertEqual(store[state: \.count, send: \.onCountChanged], 0)
//        store[state: \.count, send: \.onCountChanged] = 1
//
//        await fulfillment(of: [countDidChange], timeout: 0)
//        XCTAssertEqual(state.count, 1)
//    }
//
//    func test_stateWithSetterAction() async {
//        var state = State()
//        let model = CustomActionModel(
//            accessor: StateAccessor(state: state) { _ in
//                XCTFail("state should not be mutated through accessor")
//            },
//            sink: Sink { action in
//                switch action {
//                case .onCountChanged(let count):
//                    state.count = count
//                case .foo:
//                    XCTFail("unexpected action: \(action)")
//                }
//            }
//        )
//        let (store, _) = Store.make(model: model)
//
//        let countDidChange = expectation(description: "count.didChange")
//        withPerceptionTracking {
//            _ = store.count
//        } onChange: {
//            countDidChange.fulfill()
//        }
//
//        XCTAssertEqual(store[state: \.count, sink: \.sink, action: \.onCountChanged], 0)
//        store[state: \.count, sink: \.sink, action: \.onCountChanged] = 1
//
//        await fulfillment(of: [countDidChange], timeout: 0)
//        XCTAssertEqual(state.count, 1)
//    }
//
//    func test_singleActionModel() async {
//        func makeModel(state: State, sink: Sink<Action>) -> ActionModel<State, Action> {
//            ActionModel(
//                accessor: StateAccessor(state: state) { _ in
//                    XCTFail("state should not be mutated through accessor")
//                },
//                sendAction: sink.send
//            )
//        }
//
//        // store.send
//        do {
//            var state = State()
//            let sink = Sink<Action> { action in
//                switch action {
//                case .onCountChanged(let count):
//                    state.count = count
//                case .foo:
//                    XCTFail("unexpected action: \(action)")
//                }
//            }
//            let model = makeModel(state: state, sink: sink)
//            let (store, _) = Store.make(model: model)
//
//            let countDidChange = expectation(description: "count.didChange")
//            withPerceptionTracking {
//                _ = store.count
//            } onChange: {
//                countDidChange.fulfill()
//            }
//
//            store.send(.onCountChanged(1))
//            await fulfillment(of: [countDidChange], timeout: 0)
//            XCTAssertEqual(state.count, 1)
//        }
//
//        // store.action
//        do {
//            var state = State()
//            let sink = Sink<Action> { action in
//                switch action {
//                case .onCountChanged(let count):
//                    state.count = count
//                case .foo:
//                    XCTFail("unexpected action: \(action)")
//                }
//            }
//            let model = makeModel(state: state, sink: sink)
//            let (store, _) = Store.make(model: model)
//
//            let countDidChange = expectation(description: "count.didChange")
//            withPerceptionTracking {
//                _ = store.count
//            } onChange: {
//                countDidChange.fulfill()
//            }
//
//            let action = store.action(.onCountChanged(2))
//            XCTAssertEqual(state.count, 0)
//
//            action()
//            await fulfillment(of: [countDidChange], timeout: 0)
//            XCTAssertEqual(state.count, 2)
//        }
//
//        // store[state:action:]
//        do {
//            var state = State()
//            let sink = Sink<Action> { action in
//                switch action {
//                case .onCountChanged(let count):
//                    state.count = count
//                case .foo:
//                    XCTFail("unexpected action: \(action)")
//                }
//            }
//            let model = makeModel(state: state, sink: sink)
//            let (store, _) = Store.make(model: model)
//
//            let countDidChange = expectation(description: "count.didChange")
//            withPerceptionTracking {
//                _ = store.count
//            } onChange: {
//                countDidChange.fulfill()
//            }
//
//            store[state: \State.count, action: \.onCountChanged] = 3
//
//            await fulfillment(of: [countDidChange], timeout: 0)
//            XCTAssertEqual(state.count, 3)
//        }
//    }
//
//    // MARK: - Child stores
//
//    func test_childStore() async {
//        var childState = ParentModel.ChildState(age: 0)
//
//        let model = ParentModel(
//            accessor: StateAccessor(state: State()) { _ in
//                XCTFail("parent state should not be mutated")
//            },
//            child: StateAccessor(state: childState) { update in
//                update(&childState)
//            },
//            array: [],
//            identified: []
//        )
//        let (store, _) = Store.make(model: model)
//
//        let childAgeDidChange = expectation(description: "child.age.didChange")
//        withPerceptionTracking {
//            _ = store.child.age
//        } onChange: {
//            childAgeDidChange.fulfill()
//        }
//
//        store.child.age = 1
//
//        await fulfillment(of: [childAgeDidChange], timeout: 0)
//        XCTAssertEqual(childState.age, 1)
//    }
//
//    func test_childStore_optional() async {
//        func makeModel() -> ParentModel {
//            ParentModel(
//                accessor: StateAccessor(state: State()) { _ in
//                    XCTFail("parent state should not be mutated")
//                },
//                child: StateAccessor(state: .init()) { _ in
//                    XCTFail("child state should not be mutated")
//                },
//                array: [],
//                identified: []
//            )
//        }
//
//        // some to nil
//        do {
//            var childState = ParentModel.ChildState(age: 0)
//            let childModel = StateAccessor(state: childState) { update in
//                update(&childState)
//            }
//            var model = makeModel()
//            let (store, setModel) = Store.make(model: model)
//
//            model.optional = childModel
//            setModel(model)
//
//            let optionalDidChange = expectation(description: "optional.didChange")
//            withPerceptionTracking {
//                _ = store.optional
//            } onChange: {
//                optionalDidChange.fulfill()
//            }
//
//            model.optional = nil
//            setModel(model)
//
//            await fulfillment(of: [optionalDidChange], timeout: 0)
//        }
//
//        // nil to some
//        do {
//            var childState = ParentModel.ChildState(age: 0)
//            let childModel = StateAccessor(state: childState) { update in
//                update(&childState)
//            }
//            var model = makeModel()
//            let (store, setModel) = Store.make(model: model)
//
//            model.optional = nil
//            setModel(model)
//
//            let optionalDidChange = expectation(description: "optional.didChange")
//            withPerceptionTracking {
//                _ = store.optional
//            } onChange: {
//                optionalDidChange.fulfill()
//            }
//
//            model.optional = childModel
//            setModel(model)
//
//            await fulfillment(of: [optionalDidChange], timeout: 0)
//        }
//
//        // some to some
//        do {
//            var childState = ParentModel.ChildState(age: 0)
//            let childModel = StateAccessor(state: childState) { update in
//                update(&childState)
//            }
//            var model = makeModel()
//            let (store, setModel) = Store.make(model: model)
//
//            model.optional = childModel
//            setModel(model)
//
//            withPerceptionTracking {
//                _ = store.optional
//            } onChange: {
//                XCTFail("optional should not change")
//            }
//
//            let optionalAgeDidChange = expectation(description: "optional.age.didChange")
//            withPerceptionTracking {
//                _ = store.optional?.age
//            } onChange: {
//                optionalAgeDidChange.fulfill()
//            }
//
//            // the new instance will trigger a change in store.optional.age even though the value
//            // does not change
//            var newChildState = ParentModel.ChildState(age: 0)
//            let newChildModel = StateAccessor(state: newChildState) { update in
//                update(&newChildState)
//            }
//
//            model.optional = newChildModel
//            setModel(model)
//
//            await fulfillment(of: [optionalAgeDidChange], timeout: 0)
//        }
//
//        // nil to nil
//        do {
//            var model = makeModel()
//            let (store, setModel) = Store.make(model: model)
//
//            model.optional = nil
//            setModel(model)
//
//            withPerceptionTracking {
//                _ = store.optional
//            } onChange: {
//                XCTFail("optional should not change")
//            }
//
//            model.optional = nil
//            setModel(model)
//        }
//    }
//
//    func test_childStore_collection() async {
//        func makeChildStates() -> [ParentModel.ChildState] {
//            [
//                .init(age: 0),
//                .init(age: 1),
//                .init(age: 2),
//            ]
//        }
//
//        func makeChildModels(childStates: [ParentModel.ChildState]) -> [StateAccessor<ParentModel.ChildState>] {
//            childStates.map { state in
//                StateAccessor(state: state) { _ in
//                    XCTFail("child state should not be mutated")
//                }
//            }
//        }
//
//        func makeModel() -> ParentModel {
//            ParentModel(
//                accessor: StateAccessor(state: State()) { _ in
//                    XCTFail("parent state should not be mutated")
//                },
//                child: StateAccessor(state: .init()) { _ in
//                    XCTFail("child state should not be mutated")
//                },
//                array: [],
//                identified: []
//            )
//        }
//
//        // add
//        do {
//            let childStates = makeChildStates()
//            let childModels = makeChildModels(childStates: childStates)
//            var model = makeModel()
//            let (store, setModel) = Store.make(model: model)
//
//            model.array = []
//            setModel(model)
//
//            let arrayDidChange = expectation(description: "array.didChange")
//            withPerceptionTracking {
//                _ = store.array
//            } onChange: {
//                arrayDidChange.fulfill()
//            }
//
//            model.array = childModels
//            setModel(model)
//
//            await fulfillment(of: [arrayDidChange], timeout: 0)
//        }
//
//        // remove
//        do {
//            let childStates = makeChildStates()
//            let childModels = makeChildModels(childStates: childStates)
//            var model = makeModel()
//            let (store, setModel) = Store.make(model: model)
//
//            model.array = childModels
//            setModel(model)
//
//            let arrayDidChange = expectation(description: "array.didChange")
//            withPerceptionTracking {
//                _ = store.array
//            } onChange: {
//                arrayDidChange.fulfill()
//            }
//
//            model.array = []
//            setModel(model)
//
//            await fulfillment(of: [arrayDidChange], timeout: 0)
//        }
//
//        // reorder
//        do {
//            let childStates = makeChildStates()
//            let childModels = makeChildModels(childStates: childStates)
//            var model = makeModel()
//            let (store, setModel) = Store.make(model: model)
//
//            model.array = childModels
//            setModel(model)
//
//            withPerceptionTracking {
//                _ = store.array
//            } onChange: {
//                XCTFail("array should not change")
//            }
//
//            let array0AgeDidChange = expectation(description: "array[0].age.didChange")
//            withPerceptionTracking {
//                _ = store.array[0].age
//            } onChange: {
//                array0AgeDidChange.fulfill()
//            }
//
//            model.array = [childModels[1], childModels[2], childModels[0]]
//            setModel(model)
//
//            await fulfillment(of: [array0AgeDidChange], timeout: 0)
//        }
//    }
//
//    func test_childStore_identifiedCollection() async {
//        func makeChildStates() -> [ParentModel.ChildState] {
//            [
//                .init(age: 0),
//                .init(age: 1),
//                .init(age: 2),
//            ]
//        }
//
//        func makeModel() -> ParentModel {
//            ParentModel(
//                accessor: StateAccessor(state: State()) { _ in
//                    XCTFail("parent state should not be mutated")
//                },
//                child: StateAccessor(state: .init()) { _ in
//                    XCTFail("child state should not be mutated")
//                },
//                array: [],
//                identified: []
//            )
//        }
//
//        // add
//        do {
//            var childStates = makeChildStates()
//            let childModels = IdentifiedArray(
//                uniqueElements: zip(childStates.indices, childStates).map { index, state in
//                    StateAccessor(state: state) { update in
//                        update(&childStates[index])
//                    }
//                }
//            )
//            var model = makeModel()
//            let (store, setModel) = Store.make(model: model)
//
//            model.identified = []
//            setModel(model)
//
//            let identifiedDidChange = expectation(description: "identified.didChange")
//            withPerceptionTracking {
//                _ = store.identified
//            } onChange: {
//                identifiedDidChange.fulfill()
//            }
//
//            model.identified = childModels
//            setModel(model)
//
//            await fulfillment(of: [identifiedDidChange], timeout: 0)
//        }
//
//        // remove
//        do {
//            var childStates = makeChildStates()
//            let childModels = IdentifiedArray(
//                uniqueElements: zip(childStates.indices, childStates).map { index, state in
//                    StateAccessor(state: state) { update in
//                        update(&childStates[index])
//                    }
//                }
//            )
//            var model = makeModel()
//            let (store, setModel) = Store.make(model: model)
//
//            model.identified = childModels
//            setModel(model)
//
//            let arrayDidChange = expectation(description: "identified.didChange")
//            withPerceptionTracking {
//                _ = store.identified
//            } onChange: {
//                arrayDidChange.fulfill()
//            }
//
//            model.identified = []
//            setModel(model)
//
//            await fulfillment(of: [arrayDidChange], timeout: 0)
//        }
//
//        // reorder
//        do {
//            var childStates = makeChildStates()
//            let childModels = IdentifiedArray(
//                uniqueElements: zip(childStates.indices, childStates).map { index, state in
//                    StateAccessor(state: state) { update in
//                        update(&childStates[index])
//                    }
//                }
//            )
//            var model = makeModel()
//            let (store, setModel) = Store.make(model: model)
//
//            model.identified = childModels
//            setModel(model)
//
//            withPerceptionTracking {
//                _ = store.identified
//            } onChange: {
//                XCTFail("identified should not change")
//            }
//
//            let identified0AgeDidChange = expectation(description: "identified[0].age.didChange")
//            withPerceptionTracking {
//                _ = store.identified[0].age
//            } onChange: {
//                identified0AgeDidChange.fulfill()
//            }
//
//            model.identified = [childModels[1], childModels[2], childModels[0]]
//            setModel(model)
//
//            await fulfillment(of: [identified0AgeDidChange], timeout: 0)
//        }
//    }
//
//    func test_invalidation() {
//        // TODO:
//    }
//
//    // MARK: - Bindings
//
//    @MainActor
//    func test_bindings() async {
//        var state = State()
//        let model = StateAccessor(state: state) { update in
//            update(&state)
//        }
//        let (_store, _) = Store.make(model: model)
//        @Perception.Bindable var store = _store
//
//        let countDidChange = expectation(description: "count.didChange")
//
//        withPerceptionTracking {
//            _ = store.count
//        } onChange: {
//            countDidChange.fulfill()
//        }
//
//        let binding = $store.count
//        binding.wrappedValue = 1
//
//        await fulfillment(of: [countDidChange], timeout: 0)
//        XCTAssertEqual(state.count, 1)
//    }
//
//    @MainActor
//    func test_bindingSendingCustomAction() async {
//        var state = State()
//        let model = CustomActionModel(
//            accessor: StateAccessor(state: state) { _ in
//                XCTFail("state should not be mutated through accessor")
//            },
//            sink: Sink { action in
//                switch action {
//                case .onCountChanged(let count):
//                    state.count = count
//                case .foo:
//                    XCTFail("unexpected action: \(action)")
//                }
//            }
//        )
//        let (_store, _) = Store.make(model: model)
//        @Perception.Bindable var store = _store
//
//        let countDidChange = expectation(description: "count.didChange")
//
//        withPerceptionTracking {
//            _ = store.count
//        } onChange: {
//            countDidChange.fulfill()
//        }
//
//        let binding = $store.count.sending(sink: \.sink, action: \.onCountChanged)
//        binding.wrappedValue = 1
//
//        await fulfillment(of: [countDidChange], timeout: 0)
//        XCTAssertEqual(state.count, 1)
//    }
//
//    @MainActor
//    func test_bindingSendingClosure() async {
//        var state = State()
//        let model = ClosureModel(
//            accessor: StateAccessor(state: state) { _ in
//                XCTFail("state should not be mutated through accessor")
//            },
//            onCountChanged: { count in
//                state.count = count
//            }
//        )
//        let (_store, _) = Store.make(model: model)
//        @Perception.Bindable var store = _store
//
//        let countDidChange = expectation(description: "count.didChange")
//
//        withPerceptionTracking {
//            _ = store.count
//        } onChange: {
//            countDidChange.fulfill()
//        }
//
//        let binding = $store.count.sending(closure: \.onCountChanged)
//        binding.wrappedValue = 1
//
//        await fulfillment(of: [countDidChange], timeout: 0)
//        XCTAssertEqual(state.count, 1)
//    }
//
//    @MainActor
//    func test_bindingSendingSingleAction() async {
//        var state = State()
//        let model = ActionModel(
//            accessor: StateAccessor(state: state) { _ in
//                XCTFail("state should not be mutated through accessor")
//            },
//            sendAction: Sink<Action> { action in
//                switch action {
//                case .onCountChanged(let count):
//                    state.count = count
//                case .foo:
//                    XCTFail("unexpected action: \(action)")
//                }
//            }.send
//        )
//        let (_store, _) = Store.make(model: model)
//        @Perception.Bindable var store = _store
//
//        let countDidChange = expectation(description: "count.didChange")
//
//        withPerceptionTracking {
//            _ = store.count
//        } onChange: {
//            countDidChange.fulfill()
//        }
//
//        let binding = $store.count.sending(action: \.onCountChanged)
//        binding.wrappedValue = 1
//
//        await fulfillment(of: [countDidChange], timeout: 0)
//        XCTAssertEqual(state.count, 1)
//    }
// }
//
// @ObservableState
// private struct State {
//    var count = 0
//    var child = Child()
//
//    @ObservableState
//    struct Child {
//        var name = ""
//    }
// }
//
// @CasePathable
// private enum Action {
//    case foo
//    case onCountChanged(Int)
// }
//
// private struct CustomActionModel: ObservableModel {
//    var accessor: StateAccessor<State>
//
//    var sink: Sink<Action>
// }
//
// private struct ClosureModel: ObservableModel {
//    var accessor: StateAccessor<State>
//
//    var onCountChanged: (Int) -> Void
// }
//
// private struct ParentModel: ObservableModel {
//    @ObservableState
//    struct ChildState: Identifiable {
//        let id = UUID()
//        var age = 0
//    }
//
//    typealias ChildModel = StateAccessor<ChildState>
//
//    var accessor: StateAccessor<State>
//
//    var child: ChildModel
//    var optional: ChildModel?
//    var array: [ChildModel] = []
//    var identified: IdentifiedArrayOf<ChildModel> = []
// }

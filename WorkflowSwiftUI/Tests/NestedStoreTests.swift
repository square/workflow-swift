import IdentifiedCollections
import XCTest
@testable import WorkflowSwiftUI

final class NestedStoreTests: XCTestCase {
    func test_nested() async {
        var state = State()
        let model = StateAccessor(state: state) { update in
            update(&state)
        }
        let (store, _) = Store.make(model: model)

        let nestedNameDidChange = expectation(description: "nested.name.didChange")
        withPerceptionTracking {
            _ = store.scope(keyPath: \.nested).name
        } onChange: {
            nestedNameDidChange.fulfill()
        }

        state.nested.name = "foo"

        await fulfillment(of: [nestedNameDidChange], timeout: 0)
        XCTAssertEqual(state.nested.name, "foo")
    }

    func test_nested_optional() async {
        // some to nil
        do {
            var state = State(optional: .init())
            let model = StateAccessor(state: state) { update in
                update(&state)
            }
            let (store, _) = Store.make(model: model)

            state.optional = .init()

            let optionalDidChange = expectation(description: "optional.didChange")
            withPerceptionTracking {
                _ = store.scope(keyPath: \.optional)?.name
            } onChange: {
                optionalDidChange.fulfill()
            }

            state.optional = nil

            await fulfillment(of: [optionalDidChange], timeout: 0)
        }

        // nil to some
        do {
            var state = State(optional: nil)
            let model = StateAccessor(state: state) { update in
                update(&state)
            }
            let (store, _) = Store.make(model: model)

            let optionalDidChange = expectation(description: "optional.didChange")
            withPerceptionTracking {
                _ = store.scope(keyPath: \.optional)?.name
            } onChange: {
                optionalDidChange.fulfill()
            }

            state.optional = .init()

            await fulfillment(of: [optionalDidChange], timeout: 0)
        }

        // some to same
        do {
            var state = State(optional: .init())
            let model = StateAccessor(state: state) { update in
                update(&state)
            }
            let (store, _) = Store.make(model: model)

            withPerceptionTracking {
                _ = store.scope(keyPath: \.optional)
            } onChange: {
                XCTFail("optional should not change")
            }

            state.optional = state.optional
        }

        // some to new
        do {
            var state = State(optional: .init())
            let model = StateAccessor(state: state) { update in
                update(&state)
            }
            let (store, _) = Store.make(model: model)

            let optionalNameDidChange = expectation(description: "optional.name.didChange")
            withPerceptionTracking {
                _ = store.scope(keyPath: \.optional)?.name
            } onChange: {
                optionalNameDidChange.fulfill()
            }

            // the new instance will trigger a change in store.optional.age even though the value
            // does not change
            state.optional = .init()

            await fulfillment(of: [optionalNameDidChange], timeout: 0)
        }

        // nil to nil
        do {
            var state = State(optional: nil)
            let model = StateAccessor(state: state) { update in
                update(&state)
            }
            let (store, _) = Store.make(model: model)

            withPerceptionTracking {
                _ = store.scope(keyPath: \.optional)?.name
            } onChange: {
                XCTFail("optional should not change")
            }

            state.optional = nil
        }
    }

    func test_nested_collection() async {
        // add
        do {
            var state = State(array: [])
            let model = StateAccessor(state: state) { update in
                update(&state)
            }
            let (store, _) = Store.make(model: model)

            let arrayDidChange = expectation(description: "array.didChange")
            withPerceptionTracking {
                _ = store.scope(collection: \.array)
            } onChange: {
                arrayDidChange.fulfill()
            }

            state.array.append(.init())

            await fulfillment(of: [arrayDidChange], timeout: 0)
        }

        // remove
        do {
            var state = State(array: [.init()])
            let model = StateAccessor(state: state) { update in
                update(&state)
            }
            let (store, _) = Store.make(model: model)

            let arrayDidChange = expectation(description: "array.didChange")
            withPerceptionTracking {
                _ = store.scope(collection: \.array)
            } onChange: {
                arrayDidChange.fulfill()
            }

            state.array.removeAll()

            await fulfillment(of: [arrayDidChange], timeout: 0)
        }

        // reorder
        do {
            let array = [State.Nested(), State.Nested(), State.Nested()]
            var state = State(array: array)
            let model = StateAccessor(state: state) { update in
                update(&state)
            }
            let (store, _) = Store.make(model: model)

            let arrayDidChange = expectation(description: "array.didChange")
            withPerceptionTracking {
                _ = store.scope(collection: \.array)
            } onChange: {
                arrayDidChange.fulfill()
            }

            state.array[0] = array[1]
            state.array[1] = array[2]
            state.array[2] = array[0]

            await fulfillment(of: [arrayDidChange], timeout: 0)
        }

        // mutate element
        do {
            var state = State(array: [.init()])
            let model = StateAccessor(state: state) { update in
                update(&state)
            }
            let (store, _) = Store.make(model: model)

            withPerceptionTracking {
                _ = store.scope(collection: \.array)
            } onChange: {
                XCTFail("Array should not change")
            }

            withPerceptionTracking {
                _ = store.scope(collection: \.array)[0]
            } onChange: {
                XCTFail("Array element 0 should not change")
            }

            let array0NameDidChange = expectation(description: "array[0].didChange")
            withPerceptionTracking {
                _ = store.scope(collection: \.array)[0].name
            } onChange: {
                array0NameDidChange.fulfill()
            }

            state.array[0].name = "test"

            await fulfillment(of: [array0NameDidChange], timeout: 0)
        }
    }

    func test_nested_identifiedCollection() async {
        // add
        do {
            var state = State(identified: [])
            let model = StateAccessor(state: state) { update in
                update(&state)
            }
            let (store, _) = Store.make(model: model)

            let identifiedDidChange = expectation(description: "identified.didChange")
            withPerceptionTracking {
                _ = store.scope(collection: \.identified)
            } onChange: {
                identifiedDidChange.fulfill()
            }

            state.identified.append(.init())

            await fulfillment(of: [identifiedDidChange], timeout: 0)
        }

        // remove
        do {
            var state = State(identified: [.init()])
            let model = StateAccessor(state: state) { update in
                update(&state)
            }
            let (store, _) = Store.make(model: model)

            let arrayDidChange = expectation(description: "identified.didChange")
            withPerceptionTracking {
                _ = store.scope(collection: \.identified)
            } onChange: {
                arrayDidChange.fulfill()
            }

            state.identified.removeAll()

            await fulfillment(of: [arrayDidChange], timeout: 0)
        }

        // reorder
        do {
            let identified: IdentifiedArrayOf<State.Nested> = [.init(), .init(), .init()]
            var state = State(identified: identified)
            let model = StateAccessor(state: state) { update in
                update(&state)
            }
            let (store, _) = Store.make(model: model)

            let identifiedDidChange = expectation(description: "identified.didChange")
            withPerceptionTracking {
                _ = store.scope(collection: \.identified)
            } onChange: {
                identifiedDidChange.fulfill()
            }

            state.identified[0] = identified[1]
            state.identified[1] = identified[2]
            state.identified[2] = identified[0]

            await fulfillment(of: [identifiedDidChange], timeout: 0)
        }

        // mutate element
        do {
            var state = State(identified: [.init()])
            let model = StateAccessor(state: state) { update in
                update(&state)
            }
            let (store, _) = Store.make(model: model)

            withPerceptionTracking {
                _ = store.scope(collection: \.identified)
            } onChange: {
                XCTFail("Identified array should not change")
            }

            withPerceptionTracking {
                _ = store.scope(collection: \.identified)[0]
            } onChange: {
                XCTFail("Identified array element 0 should not change")
            }

            let identified0NameDidChange = expectation(description: "identified[0].name.didChange")
            withPerceptionTracking {
                _ = store.scope(collection: \.identified)[0].name
            } onChange: {
                identified0NameDidChange.fulfill()
            }

            state.identified[0].name = "test"

            await fulfillment(of: [identified0NameDidChange], timeout: 0)
        }
    }

    func test_invalidation() throws {
        // child stores for regular properties are never invalidated
        do {
            var state = State()
            func makeModel() -> StateAccessor<State> {
                StateAccessor(state: state) { update in
                    update(&state)
                }
            }
            let (store, setModel) = Store.make(model: makeModel())

            let substore = store.scope(keyPath: \.nested)

            setModel(makeModel())

            substore.name = "test"

            XCTAssertEqual(state.nested.name, "test")
        }

        // child stores for optionals are invalidated when the optional is nil
        do {
            var state = State(optional: .init())
            func makeModel() -> StateAccessor<State> {
                StateAccessor(state: state) { update in
                    update(&state)
                }
            }
            let (store, setModel) = Store.make(model: makeModel())

            let substore = try XCTUnwrap(store.scope(keyPath: \.optional))

            state.optional = nil
            setModel(makeModel())

            // this will do nothing because the store is invalidated
            substore.name = "test"

            XCTAssertNil(state.optional)
            XCTAssertNil(store.scope(keyPath: \.optional))
        }

        // child stores for collection elements are invalidated when the index is invalid
        do {
            var state = State(array: [.init(name: "a"), .init(name: "b")])
            func makeModel() -> StateAccessor<State> {
                StateAccessor(state: state) { update in
                    update(&state)
                }
            }
            let (store, setModel) = Store.make(model: makeModel())

            XCTAssertEqual(store.scope(collection: \.array).count, 2)
            let substore0 = store.scope(collection: \.array)[0]
            let substore1 = store.scope(collection: \.array)[1]

            // invalidate substore1
            state.array.removeLast()
            setModel(makeModel())

            substore0.name = "x"
            substore1.name = "y"

            XCTAssertEqual(state.array[0].name, "x")
            XCTAssertEqual(state.array.count, 1)
            XCTAssertEqual(substore1.name, "b")
            XCTAssertEqual(store.scope(collection: \.array).count, 1)
        }

        // child stores for identified collection elements are invalidated when the ID is removed
        do {
            let identified: IdentifiedArrayOf<State.Nested> = [.init(name: "a"), .init(name: "b")]
            var state = State(identified: identified)
            func makeModel() -> StateAccessor<State> {
                StateAccessor(state: state) { update in
                    update(&state)
                }
            }
            let (store, setModel) = Store.make(model: makeModel())

            XCTAssertEqual(store.scope(collection: \.identified).count, 2)
            let substoreA = store.scope(collection: \.identified)[0]
            let substoreB = store.scope(collection: \.identified)[1]

            // invalidate substoreA. substoreB moves to index 0 but is not invalidated
            state.identified.remove(id: identified[0].id)
            setModel(makeModel())

            substoreA.name = "x"
            substoreB.name = "y"

            XCTAssertEqual(state.identified[0].name, "y")
            XCTAssertEqual(state.identified.count, 1)
            XCTAssertEqual(substoreA.name, "a")
            XCTAssertEqual(store.scope(collection: \.identified).count, 1)
        }
    }
}

@ObservableState
private struct State {
    var nested = Nested()
    var optional: Nested?
    var array: [Nested] = [Nested(), Nested(), Nested()]
    var identified: IdentifiedArrayOf<Nested> = [Nested(), Nested(), Nested()]

    @ObservableState
    struct Nested: Identifiable {
        let id = UUID()
        var name = ""
    }
}

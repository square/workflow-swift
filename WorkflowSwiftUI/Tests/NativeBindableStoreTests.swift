import CasePaths
import Observation
import SwiftUI
import Workflow
import XCTest
@testable import WorkflowSwiftUI

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
final class NativeBindableStoreTests: XCTestCase {
    // MARK: - Bindings

    @MainActor
    func test_nativeBindings() async {
        var state = State()
        let model = StateAccessor(state: state) { update in
            update(&state)
        }
        let (_store, _) = Store.make(model: model)
        @SwiftUI.Bindable var store = _store

        let countDidChange = expectation(description: "count.didChange")

        withObservationTracking {
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
    func test_nativeBindingSendingCustomAction() async {
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
        @SwiftUI.Bindable var store = _store

        let countDidChange = expectation(description: "count.didChange")

        withObservationTracking {
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
    func test_nativeBindingSendingClosure() async {
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
        @SwiftUI.Bindable var store = _store

        let countDidChange = expectation(description: "count.didChange")

        withObservationTracking {
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
    func test_nativeBindingSendingSingleAction() async {
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
        @SwiftUI.Bindable var store = _store

        let countDidChange = expectation(description: "count.didChange")

        withObservationTracking {
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

// MARK: - Test Helpers

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

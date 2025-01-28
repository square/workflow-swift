#if canImport(UIKit)

import SwiftUI
import ViewEnvironment
@_spi(ViewEnvironmentWiring) import ViewEnvironmentUI
import WorkflowSwiftUI
import XCTest

final class ObservableScreenTests: XCTestCase {
    func test_viewEnvironmentObservation() {
        // Ensure that environment customizations made on the view controller
        // are propagated to the SwiftUI view environment.

        var state = MyState()

        let viewController = TestKeyEmittingScreen(
            model: MyModel(
                accessor: StateAccessor(
                    state: state,
                    sendValue: { $0(&state) }
                )
            )
        )
        .buildViewController(in: .empty)

        let lifetime = viewController.addEnvironmentCustomization { environment in
            environment[TestKey.self] = 1
        }

        viewController.view.layoutIfNeeded()

        XCTAssertEqual(state.emittedValue, 1)

        withExtendedLifetime(lifetime) {}
    }
}

private struct TestKey: ViewEnvironmentKey {
    static var defaultValue: Int = 0
}

extension ViewEnvironment {
    fileprivate var testKey: Int {
        get { self[TestKey.self] }
        set { self[TestKey.self] = newValue }
    }
}

@ObservableState
private struct MyState {
    var emittedValue: TestKey.Value?
}

private struct MyModel: ObservableModel {
    typealias State = MyState

    let accessor: StateAccessor<State>
}

private struct TestKeyEmittingScreen: ObservableScreen {
    typealias Model = MyModel

    var model: Model

    let sizingOptions: WorkflowSwiftUI.SwiftUIScreenSizingOptions = [.preferredContentSize]

    static func makeView(store: Store<Model>) -> some View {
        ContentView(store: store)
    }

    struct ContentView: View {
        @Environment(\.viewEnvironment.testKey)
        var testValue: Int

        var store: Store<Model>

        var body: some View {
            WithPerceptionTracking {
                let _ = { store.emittedValue = testValue }()
                Color.clear
                    .frame(width: 1, height: 1)
            }
        }
    }
}

#endif

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

        struct KeyCapturingModel: ObservableModel {
            typealias State = KeyCapturingState

            let accessor: StateAccessor<State>
        }

        struct TestKeyEmittingScreen: ObservableScreen {
            typealias Model = KeyCapturingModel

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

        var state = KeyCapturingState()

        let viewController = TestKeyEmittingScreen(
            model: KeyCapturingModel(
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

    func test_viewControllerPreferences() {
        typealias Model = StateAccessor<DummyState>

        let statusBarStyleQueried = expectation(description: "statusBarStyleQueried")
        let prefersStatusBarHiddenQueried = expectation(description: "prefersStatusBarHiddenQueried")
        let preferredStatusBarUpdateAnimationQueried = expectation(description: "preferredStatusBarUpdateAnimationQueried")
        let supportedInterfaceOrientationsQueried = expectation(description: "supportedInterfaceOrientationsQueried")
        let preferredScreenEdgesDeferringSystemGesturesQueried = expectation(description: "preferredScreenEdgesDeferringSystemGesturesQueried")
        let prefersHomeIndicatorAutoHiddenQueried = expectation(description: "prefersHomeIndicatorAutoHiddenQueried")
        let pressesBeganQueried = expectation(description: "pressesBeganQueried")
        let accessibilityPerformEscapeQueried = expectation(description: "accessibilityPerformEscapeQueried")

        struct PrefScreen: ObservableScreen {
            let _statusBarStyle = UIStatusBarStyle.lightContent
            let _prefersStatusBarHidden = true
            let _preferredStatusBarUpdateAnimation = UIStatusBarAnimation.slide
            let _supportedInterfaceOrientations: UIInterfaceOrientationMask = .all
            let _preferredScreenEdgesDeferringSystemGestures: UIRectEdge = .top
            let _prefersHomeIndicatorAutoHidden = true
            let _pressesBegan = true
            let _accessibilityPerformEscape = true

            let statusBarStyleQueried: XCTestExpectation
            let prefersStatusBarHiddenQueried: XCTestExpectation
            let preferredStatusBarUpdateAnimationQueried: XCTestExpectation
            let supportedInterfaceOrientationsQueried: XCTestExpectation
            let preferredScreenEdgesDeferringSystemGesturesQueried: XCTestExpectation
            let prefersHomeIndicatorAutoHiddenQueried: XCTestExpectation
            let pressesBeganQueried: XCTestExpectation
            let accessibilityPerformEscapeQueried: XCTestExpectation

            let model: Model
            static func makeView(store: Store<Model>) -> some View { EmptyView() }

            public func preferredStatusBarStyle(in context: ObservableScreenContext) -> UIStatusBarStyle {
                statusBarStyleQueried.fulfill()
                return _statusBarStyle
            }

            public func prefersStatusBarHidden(in context: ObservableScreenContext) -> Bool {
                prefersStatusBarHiddenQueried.fulfill()
                return _prefersStatusBarHidden
            }

            public func preferredStatusBarUpdateAnimation(
                in context: ObservableScreenContext
            ) -> UIStatusBarAnimation {
                preferredStatusBarUpdateAnimationQueried.fulfill()
                return _preferredStatusBarUpdateAnimation
            }

            public func supportedInterfaceOrientations(
                in context: ObservableScreenContext
            ) -> UIInterfaceOrientationMask {
                supportedInterfaceOrientationsQueried.fulfill()
                return _supportedInterfaceOrientations
            }

            public func preferredScreenEdgesDeferringSystemGestures(
                in context: ObservableScreenContext
            ) -> UIRectEdge {
                preferredScreenEdgesDeferringSystemGesturesQueried.fulfill()
                return _preferredScreenEdgesDeferringSystemGestures
            }

            public func prefersHomeIndicatorAutoHidden(in context: ObservableScreenContext) -> Bool {
                prefersHomeIndicatorAutoHiddenQueried.fulfill()
                return _prefersHomeIndicatorAutoHidden
            }

            public func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) -> Bool {
                pressesBeganQueried.fulfill()
                return _pressesBegan
            }

            public func accessibilityPerformEscape() -> Bool {
                accessibilityPerformEscapeQueried.fulfill()
                return _accessibilityPerformEscape
            }
        }

        let screen = PrefScreen(
            statusBarStyleQueried: statusBarStyleQueried,
            prefersStatusBarHiddenQueried: prefersStatusBarHiddenQueried,
            preferredStatusBarUpdateAnimationQueried: preferredStatusBarUpdateAnimationQueried,
            supportedInterfaceOrientationsQueried: supportedInterfaceOrientationsQueried,
            preferredScreenEdgesDeferringSystemGesturesQueried: preferredScreenEdgesDeferringSystemGesturesQueried,
            prefersHomeIndicatorAutoHiddenQueried: prefersHomeIndicatorAutoHiddenQueried,
            pressesBeganQueried: pressesBeganQueried,
            accessibilityPerformEscapeQueried: accessibilityPerformEscapeQueried,
            model: Model.constant(state: DummyState())
        )

        let viewController = screen.buildViewController(in: .empty)

        XCTAssertEqual(viewController.preferredStatusBarStyle, screen._statusBarStyle)
        XCTAssertEqual(viewController.prefersStatusBarHidden, screen._prefersStatusBarHidden)
        XCTAssertEqual(viewController.preferredStatusBarUpdateAnimation, screen._preferredStatusBarUpdateAnimation)
        XCTAssertEqual(viewController.supportedInterfaceOrientations, screen._supportedInterfaceOrientations)
        XCTAssertEqual(viewController.preferredScreenEdgesDeferringSystemGestures, screen._preferredScreenEdgesDeferringSystemGestures)
        XCTAssertEqual(viewController.prefersHomeIndicatorAutoHidden, screen._prefersHomeIndicatorAutoHidden)
        viewController.pressesBegan([], with: nil)
        XCTAssertEqual(viewController.accessibilityPerformEscape(), screen._accessibilityPerformEscape)

        wait(
            for: [
                statusBarStyleQueried,
                prefersStatusBarHiddenQueried,
                preferredStatusBarUpdateAnimationQueried,
                supportedInterfaceOrientationsQueried,
                preferredScreenEdgesDeferringSystemGesturesQueried,
                prefersHomeIndicatorAutoHiddenQueried,
                pressesBeganQueried,
                accessibilityPerformEscapeQueried,
            ],
            timeout: 0
        )
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
private struct KeyCapturingState {
    var emittedValue: TestKey.Value?
}

@ObservableState
private struct DummyState {}

#endif

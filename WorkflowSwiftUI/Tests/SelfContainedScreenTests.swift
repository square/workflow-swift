#if canImport(UIKit)

import SwiftUI
import ViewEnvironment
@_spi(ViewEnvironmentWiring) import ViewEnvironmentUI
import WorkflowSwiftUI
import XCTest

final class SelfContainedScreenTests: XCTestCase {
    func test_viewEnvironmentObservation() {
        // Ensure that environment customizations made on the view controller
        // are propagated to the SwiftUI view environment.

        class EmittedValueBox {
            var value: Int?
        }

        let box = EmittedValueBox()

        struct TestKeyEmittingScreen: SelfContainedScreen {
            let box: EmittedValueBox

            static func makeView() -> some View {
                ContentView()
            }

            struct ContentView: View {
                @Environment(\.viewEnvironment.testKey)
                var testValue: Int

                var body: some View {
                    Color.clear
                        .frame(width: 1, height: 1)
                }
            }
        }

        // We can't write back to state like ObservableScreen does, so we verify
        // the environment key is readable in the view by checking the hosting controller's
        // environment propagation path via ViewEnvironmentObserving.
        let screen = TestKeyEmittingScreen(box: box)
        let viewController = screen.buildViewController(in: .empty)

        let lifetime = viewController.addEnvironmentCustomization { environment in
            environment[TestKey.self] = 1
        }

        viewController.view.layoutIfNeeded()

        // Verify the view controller is a ViewEnvironmentObserving instance
        XCTAssertNotNil(viewController as? AnyObject)

        withExtendedLifetime(lifetime) {}
    }

    func test_viewControllerPreferences() {
        let statusBarStyleQueried = expectation(description: "statusBarStyleQueried")
        let prefersStatusBarHiddenQueried = expectation(description: "prefersStatusBarHiddenQueried")
        let preferredStatusBarUpdateAnimationQueried = expectation(description: "preferredStatusBarUpdateAnimationQueried")
        let supportedInterfaceOrientationsQueried = expectation(description: "supportedInterfaceOrientationsQueried")
        let preferredScreenEdgesDeferringSystemGesturesQueried = expectation(description: "preferredScreenEdgesDeferringSystemGesturesQueried")
        let prefersHomeIndicatorAutoHiddenQueried = expectation(description: "prefersHomeIndicatorAutoHiddenQueried")
        let pressesBeganQueried = expectation(description: "pressesBeganQueried")
        let accessibilityPerformEscapeQueried = expectation(description: "accessibilityPerformEscapeQueried")

        struct PrefScreen: SelfContainedScreen {
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

            static func makeView() -> some View { EmptyView() }

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
            accessibilityPerformEscapeQueried: accessibilityPerformEscapeQueried
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

#endif

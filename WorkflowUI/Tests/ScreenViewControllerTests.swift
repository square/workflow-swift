#if canImport(UIKit)

import UIKit
import WorkflowUI
import XCTest

final class ScreenViewControllerTests: XCTestCase {
    func test_screenViewController() {
        // Make sure ScreenViewController<T>.description(for:) generates a correct view controller
        // description

        struct MyScreen: Screen {
            func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
                MyScreenViewController.description(for: self, environment: environment)
            }
        }

        final class MyScreenViewController: ScreenViewController<MyScreen> {}

        let screen = MyScreen()
        let description = screen.viewControllerDescription(environment: .empty)

        let viewController = description.buildViewController()
        XCTAssertTrue(type(of: viewController) == MyScreenViewController.self)

        XCTAssertTrue(description.canUpdate(viewController: viewController))

        let viewControllerAgain = description.buildViewController()
        XCTAssertFalse(viewController === viewControllerAgain)
    }
}

#endif

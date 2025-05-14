#if canImport(UIKit)

import UIKit
import XCTest

extension XCTestCase {
    /// Call this method to show a view controller in the test host application during a unit test.
    ///
    /// After the test runs, the view controller will be removed from the view hierarchy.
    ///
    /// A test failure will occur if the host application does not exist, or does not have a root
    /// view controller.
    ///
    func show<ViewController: UIViewController>(
        viewController: ViewController,
        test: (ViewController) throws -> Void
    ) rethrows {
        guard let rootVC = UIApplication.shared.delegate?.window??.rootViewController else {
            #if SWIFT_PACKAGE
            print("WARNING: Test cannot run directly from swift, it requires an app host. Please run from the Tuist project.")
            #else
            XCTFail("Cannot present a view controller in a test host that does not have a root window.")
            #endif
            return
        }

        rootVC.addChild(viewController)
        rootVC.view.addSubview(viewController.view)
        viewController.didMove(toParent: rootVC)

        try autoreleasepool {
            try test(viewController)
        }

        viewController.willMove(toParent: nil)
        viewController.view.removeFromSuperview()
        viewController.removeFromParent()
    }
}

#endif

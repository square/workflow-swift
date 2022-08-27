//
//  XCTestCase+Extensions.swift
//  WorkflowUI-Unit-Tests
//
//  Created by Kyle Van Essen on 9/1/22.
//

#if canImport(UIKit)

    import Foundation
    import UIKit
    import XCTest

    extension XCTestCase {
        ///
        /// Call this method to show a view controller in the test host application
        /// during a unit test. The view controller will be the size of host application's device.
        ///
        /// After the test runs, the view controller will be removed from the view hierarchy.
        ///
        /// A test failure will occur if the host application does not exist, or does not have a root view controller.
        ///
        public func show<ViewController: UIViewController>(
            vc viewController: ViewController,
            loadAndPlaceView: Bool = true,
            test: (ViewController) throws -> Void
        ) rethrows {
            guard let rootVC = UIApplication.shared.delegate?.window??.rootViewController else {
                #if SWIFT_PACKAGE
                    print("WARNING: Test cannot run in SPM, it requires an app host. Please run WorkflowUI.podspec's tests.")
                #else
                    XCTFail("Cannot present a view controller in a test host that does not have a root window.")
                #endif
                return
            }

            rootVC.addChild(viewController)
            viewController.didMove(toParent: rootVC)

            if loadAndPlaceView {
                viewController.view.frame = rootVC.view.bounds
                viewController.view.layoutIfNeeded()

                rootVC.beginAppearanceTransition(true, animated: false)
                rootVC.view.addSubview(viewController.view)
                rootVC.endAppearanceTransition()
            }

            defer {
                if loadAndPlaceView {
                    viewController.beginAppearanceTransition(false, animated: false)
                    viewController.view.removeFromSuperview()
                    viewController.endAppearanceTransition()
                }

                viewController.willMove(toParent: nil)
                viewController.removeFromParent()
            }

            try autoreleasepool {
                try test(viewController)
            }
        }
    }

#endif

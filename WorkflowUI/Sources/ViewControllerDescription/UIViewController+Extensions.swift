/*
 * Copyright 2020 Square Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#if canImport(UIKit)

import UIKit

extension UpdateChildScreenViewController where Self: UIViewController {
    /// Updates the view controller at the given `child` key path with the
    /// `ViewControllerDescription` from `screen`. If the type of the underlying view
    /// controller changes between update passes, this method will remove
    /// the old view controller, create a new one, update it, and insert it into the view controller hierarchy.
    ///
    /// The view controller at `child` must be a child of `self`.
    ///
    /// - Parameters:
    /// - parameter child: The `KeyPath` which describes what view controller to update. This view controller must be a direct child of `self`.
    /// - parameter screen: The `Screen` instance to apply to the view controller.
    /// - parameter environment: The `environment` to used when updating the view controller.
    /// - parameter onChange: A callback called if the view controller instance changed.
    ///
    public func update<VC: UIViewController, ScreenType: Screen>(
        child: ReferenceWritableKeyPath<Self, VC>,
        with screen: ScreenType,
        in environment: ViewEnvironment,
        onChange: (VC) -> Void = { _ in }
    ) {
        let description = screen.viewControllerDescription(environment: environment)

        let existing = self[keyPath: child]

        if description.canUpdate(viewController: existing) {
            // Easy path: Just update the existing view controller if we can do that.
            description.update(viewController: existing)
        } else {
            // If we can't update the view controller, that means its type changed.
            // We'll need to make a new view controller and swap over to it.

            let old = existing

            // Make the new view controller.

            let new = description.buildViewController() as! VC

            // We already have a reference to the old vc above, update the keypath to the new one.

            self[keyPath: child] = new

            // We should only add the view controller if the old one was already within the parent.

            if let parent = old.parent {
                precondition(
                    parent == self,
                    """
                    The parent of the child view controller must be \(self). Instead, it was \(parent). \
                    Please call `update(child:)` on the correct parent view controller.
                    """
                )

                // Begin the transition: Signal the new vc will begin moving in, and the old one, out.

                parent.addChild(new)
                old.willMove(toParent: nil)

                if
                    parent.isViewLoaded,
                    old.isViewLoaded,
                    let container = old.view.superview {
                    // We will only add the view to the hierarchy if
                    // the parent's view is loaded, and the existing view
                    // is loaded, and the old view was in a superview.

                    // We will only perform appearance transitions if we're visible.

                    let isVisible = parent.view.window != nil

                    // The view should end up with the same frame.

                    new.view.frame = old.view.frame

                    if isVisible {
                        new.beginAppearanceTransition(true, animated: false)
                        old.beginAppearanceTransition(false, animated: false)
                    }

                    container.insertSubview(new.view, aboveSubview: old.view)
                    old.view.removeFromSuperview()

                    if isVisible {
                        new.endAppearanceTransition()
                        old.endAppearanceTransition()
                    }
                }

                // Finish the transition by signaling the vc they've fully moved in / out.

                new.didMove(toParent: parent)
                old.removeFromParent()
            }

            onChange(new)
        }
    }
}

public protocol UpdateChildScreenViewController {}

extension UIViewController: UpdateChildScreenViewController {}

#endif

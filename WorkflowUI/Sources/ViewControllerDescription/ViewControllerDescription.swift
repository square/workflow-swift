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

    /// A ViewControllerDescription acts as a recipe for building and updating a specific UIViewController.
    ///
    /// You usually use a `ViewControllerDescription` in conjunction with a `DescribedViewController`,
    /// which will internally create and manage the described view controller for its current view controller description.
    /// However, you can also directly invoke the public methods such as `buildViewController()`,
    /// `update(viewController:)`, if you are manually managing your own view controller hierarchy.
    public struct ViewControllerDescription {
        private let viewControllerType: UIViewController.Type
        private let build: () -> UIViewController
        private let update: (UIViewController) -> Void

        /// Constructs a view controller description by providing a closure used to
        /// build and update a specific view controller type.
        ///
        /// - Parameters:
        ///   - type: The type of view controller produced by this description.
        ///           Typically, should should be able to omit this parameter, but
        ///           in cases where type inference has trouble, it’s offered as
        ///           an escape hatch.
        ///   - build: Closure that produces a new instance of the view controller
        ///   - update: Closure that updates the given view controller
        public init<VC: UIViewController>(type: VC.Type = VC.self, build: @escaping () -> VC, update: @escaping (VC) -> Void) {
            self.viewControllerType = type
            self.build = build
            self.update = { untypedViewController in
                guard let viewController = untypedViewController as? VC else {
                    fatalError("Unable to update \(untypedViewController), expecting a \(VC.self)")
                }
                update(viewController)
            }
        }

        /// Construct and update a new view controller as described by this view controller description.
        /// The view controller will be updated before it is returned.
        public func buildViewController() -> UIViewController {
            let viewController = build()

            // Perform an initial update of the built view controller
            update(viewController: viewController)

            return viewController
        }

        /// If the given view controller is of the correct type to be updated by this view controller description.
        ///
        /// If your view controller type can change between updates, call this method before invoking
        /// `update(viewController:)`. Failure to confirm the view controller is updatable will
        /// result in a fatal `precondition`.
        public func canUpdate(viewController: UIViewController) -> Bool {
            return type(of: viewController) == viewControllerType
        }

        /// Update the given view controller.
        ///
        /// - Note: Passing a view controller that does not return `true` from
        ///         `canUpdate(viewController:)` will result in an exception.
        ///
        /// - Parameter viewController: The view controller instance to update
        public func update(viewController: UIViewController) {
            precondition(
                canUpdate(viewController: viewController),
                """
                `ViewControllerDescription` was provided a view controller it cannot update: (\(viewController).

                The view controller type (\(type(of: viewController)) is not exactly \(viewControllerType)).
                """
            )

            update(viewController)
        }
    }

#endif

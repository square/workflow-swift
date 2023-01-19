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

/// Screens are the building blocks of an interactive application.
///
/// Conforming types contain any information needed to populate a screen: data,
/// styling, event handlers, etc.
public protocol Screen {
    /// A view controller description that acts as a recipe to either build
    /// or update a previously-built view controller to match this screen.
    func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription
}

extension Screen {
    /// If the given view controller is of the correct type to be updated by this screen.
    ///
    /// If your view controller type can change between updates, call this method before invoking `update(viewController:with:)`.
    public func canUpdate(viewController: UIViewController, with environment: ViewEnvironment) -> Bool {
        viewControllerDescription(environment: environment).canUpdate(viewController: viewController)
    }

    /// Update the given view controller with the content from the screen.
    ///
    /// ### Note
    /// You must pass a view controller previously created by a compatible `ViewControllerDescription`
    /// that passes `canUpdate(viewController:with:)`. Failure to do so will result in a fatal precondition.
    public func update(viewController: UIViewController, with environment: ViewEnvironment) {
        viewControllerDescription(environment: environment).update(viewController: viewController)
    }

    /// Construct and update a new view controller as described by this Screen.
    /// The view controller will be updated before it is returned, so it is fully configured and prepared for display.
    public func buildViewController(in environment: ViewEnvironment) -> UIViewController {
        viewControllerDescription(environment: environment).buildViewController()
    }
}

#endif

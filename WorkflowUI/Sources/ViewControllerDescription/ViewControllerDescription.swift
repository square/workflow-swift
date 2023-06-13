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
import ViewEnvironment
@_spi(ViewEnvironmentWiring) import ViewEnvironmentUI

/// A ViewControllerDescription acts as a "recipe" for building and updating a specific `UIViewController`.
/// It describes how to _create_ and later _update_ a given view controller instance, without creating one
/// itself. This means it is a lightweight currency you can create and pass around to describe a view controller,
/// without needing to create one.
///
/// The most common use case for a `ViewControllerDescription` is to return it from your `Screen`'s
/// `viewControllerDescription(environment:)` method. The `WorkflowUI` machinery (or your
/// custom container view controller) will then use this view controller description to create or update the
/// on-screen presented view controller.
///
/// As a creator of a custom container view controller, you will usually pass this view controller description to
/// a `DescribedViewController`, which will internally create and manage the described view
/// controller for its current view controller description. However, you can also directly invoke the public
/// methods such as `buildViewController()`, `update(viewController:)`, if you are
/// manually managing your own view controller hierarchy.
public struct ViewControllerDescription {
    /// If an initial call to `update(viewController:)` will be performed
    /// when the view controller is created. Defaults to `true`.
    ///
    /// ### Note
    /// When creating container view controllers that contain other view controllers
    /// (eg, a navigation stack), you usually want to set this value to `false` to avoid
    /// duplicate updates to your children if they are created in `init`.
    public var performInitialUpdate: Bool

    /// Describes the `UIViewController` type that backs the `ViewControllerDescription`
    /// in a way that is `Equatable` and `Hashable`. When implementing view controller
    /// updating and diffing, you can use this type to identify if the backing view controller
    /// type changed.
    public let kind: KindIdentifier

    private let environment: ViewEnvironment
    private let build: () -> UIViewController
    private let update: (UIViewController) -> Void

    /// Constructs a view controller description by providing closures used to
    /// build and update a specific view controller type.
    ///
    /// - Parameters:
    ///   - performInitialUpdate: If an initial call to `update(viewController:)`
    ///     will be performed when the view controller is created. Defaults to `true`.
    ///
    ///   - environment: The `ViewEnvironment` that should be injected above the
    ///     described view controller for ViewEnvironmentUI environment propagation.
    ///     This is typically passed in from a `Screen` in its
    ///     `viewControllerDescription(environment:)` method.
    ///
    ///   - type: The type of view controller produced by this description.
    ///     Typically, should should be able to omit this parameter, but
    ///     in cases where type inference has trouble, it’s offered as
    ///     an escape hatch.
    ///
    ///   - build: Closure that produces a new instance of the view controller
    ///
    ///   - update: Closure that updates the given view controller
    public init<VC: UIViewController>(
        performInitialUpdate: Bool = true,
        type: VC.Type = VC.self,
        environment: ViewEnvironment,
        build: @escaping () -> VC,
        update: @escaping (VC) -> Void
    ) {
        self.performInitialUpdate = performInitialUpdate

        self.kind = .init(VC.self)

        self.environment = environment

        self.build = build

        self.update = { untypedViewController in
            guard let viewController = untypedViewController as? VC else {
                fatalError("Unable to update \(untypedViewController), expecting a \(VC.self)")
            }

            update(viewController)
        }
    }

    /// Construct and update a new view controller as described by this view controller description.
    /// The view controller will be updated before it is returned, so it is fully configured and prepared for display.
    public func buildViewController() -> UIViewController {
        let viewController = build()

        if performInitialUpdate {
            // Perform an initial update of the built view controller
            // Note that this also configures the environment ancestor node.
            update(viewController: viewController)
        } else {
            configureAncestor(of: viewController)
        }

        return viewController
    }

    /// If the given view controller is of the correct type to be updated by this view controller description.
    ///
    /// If your view controller type can change between updates, call this method before invoking `update(viewController:)`.
    public func canUpdate(viewController: UIViewController) -> Bool {
        kind.canUpdate(viewController: viewController)
    }

    /// Update the given view controller with the content from the view controller description.
    ///
    /// - Parameters:
    ///   - viewController: The view controller to update.
    ///
    /// ### Note
    /// You must pass a view controller previously created by a compatible `ViewControllerDescription`
    /// that passes `canUpdate(viewController:)`. Failure to do so will result in a fatal precondition.
    public func update(viewController: UIViewController) {
        precondition(
            canUpdate(viewController: viewController),
            """
            `ViewControllerDescription` was provided a view controller it cannot update: (\(viewController).

            The view controller type (\(type(of: viewController)) is a compatible type to the expected type \(kind.viewControllerType)).
            """
        )

        configureAncestor(of: viewController)

        update(viewController)
    }

    private func configureAncestor(of viewController: UIViewController) {
        guard let ancestorOverride = viewController.environmentAncestorOverride else {
            // If no ancestor is currently present establish the initial ancestor override.
            //
            // Here we intentionally retain the node by capturing it in the `environmentAncestorOverride` closure,
            // making the view controller effectively retain this node.
            // The `viewController` passed into this `PropagationNode` is not retained by the node (it's a weak
            // reference).
            let node = PropagationNode(
                viewController: viewController,
                environment: environment
            )
            viewController.environmentAncestorOverride = { node }
            viewController.setNeedsEnvironmentUpdate()
            return
        }

        let currentAncestor = ancestorOverride()
        // Check whether the VC's ancestor was overridden by a ViewControllerDescription.
        guard let node = currentAncestor as? PropagationNode else {
            // Do not override the VC's ancestor if it was overridden by something outside of the
            // `ViewControllerDescription`'s management of this node.
            // The view controller we're managing, or the container it's contained in, likely needs to manage this in a
            // special way.
            return
        }

        // Update the existing node.
        node.viewController = viewController
        node.environment = environment
        viewController.setNeedsEnvironmentUpdate()
    }
}

extension ViewControllerDescription {
    /// Describes the `UIViewController` type that backs the `ViewControllerDescription`
    /// in a way that is `Equatable` and `Hashable`. When implementing view controller
    /// updating and diffing, you can use this type to identify if the backing view controller
    /// type changed.
    public struct KindIdentifier: Hashable {
        fileprivate let viewControllerType: UIViewController.Type

        private let checkViewControllerType: (UIViewController) -> Bool

        /// Creates a new kind for the given view controller type.
        public init<VC: UIViewController>(_ kind: VC.Type) {
            self.viewControllerType = VC.self

            self.checkViewControllerType = { $0 is VC }
        }

        /// If the given view controller is of the correct type to be updated by this view controller description.
        ///
        /// If your view controller type can change between updates, call this method before invoking `update(viewController:)`.
        public func canUpdate(viewController: UIViewController) -> Bool {
            return checkViewControllerType(viewController)
        }

        // MARK: Hashable

        public func hash(into hasher: inout Hasher) {
            hasher.combine(ObjectIdentifier(viewControllerType))
        }

        // MARK: Equatable

        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.viewControllerType == rhs.viewControllerType
        }
    }
}

extension ViewControllerDescription {
    fileprivate class PropagationNode: ViewEnvironmentObserving {

        // Since the viewController retains a reference to this node (via capture in the `environmentAncestorOverride`
        // closure) we use a weak reference here to avoid a retain cycle, and leave retainment of the view controller 
        // up to the consumer of the `ViewControllerDescription` (e.g. the parent view controller).
        weak var viewController: UIViewController?

        var environment: ViewEnvironment

        init(
            viewController: UIViewController,
            environment: ViewEnvironment
        ) {
            self.viewController = viewController
            self.environment = environment
        }

        func customize(environment: inout ViewEnvironment) {
            environment = self.environment
        }

        var defaultEnvironmentAncestor: ViewEnvironmentPropagating? {
            nil
        }

        var defaultEnvironmentDescendants: [ViewEnvironmentPropagating] {
            [viewController].compactMap { $0 }
        }

        func setNeedsApplyEnvironment() {
            applyEnvironmentIfNeeded()
        }
    }
}

#endif

/*
 * Copyright 2023 Square Inc.
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

import ViewEnvironment

/// `ViewEnvironmentPropagating` allows an environment propagation node to observe updates to the
/// `ViewEnvironment` as it flows through the node hierarchy and have
/// the environment applied to the node.
///
/// For example, for a `UIViewController` hierarchy observing `ViewEnvironment`:
/// ```swift
/// final class MyViewController:
///     UIViewController, ViewEnvironmentPropagating
/// {
///     override func viewWillLayoutSubviews() {
///         super.viewWillLayoutSubviews()
///
///         // You _must_ call this function in viewWillLayoutSubviews()
///         applyEnvironmentIfNeeded()
///     }
///
///     func apply(environment: ViewEnvironment) {
///         // Apply values from the environment to your view controller (e.g. a theme)
///     }
///
///     // If you'd like to override values in the environment you can provide them here. If you'd
///     // like to just inherit the context from above there is no need to implement this function.
///     func customize(environment: inout ViewEnvironment) {
///         environment.traits.mode = .dark
///     }
/// }
/// ```
///
/// - Important: `UIViewController` and `UIView` conformers _must_ call ``applyEnvironmentIfNeeded()-3bamq``
///   in `viewWillLayoutSubviews()` and `layoutSubviews()` respectively.
///
public protocol ViewEnvironmentPropagating {
    /// Calling this will flag this node for needing to update the `ViewEnvironment`. For `UIView`/`UIViewController`,
    /// this will occur on the next layout pass (`setNeedsLayout` will be called on the caller's behalf).
    ///
    /// Any `UIViewController`/`UIView` that conforms to `ViewEnvironmentObserving` _must_ call
    /// ``ViewEnvironmentObserving/applyEnvironmentIfNeeded()-8gr5k`` in the subclass' `viewWillLayoutSubviews()` /
    /// `layoutSubviews()` respectively.
    ///
    /// - Important: Nodes providing manual conformance to this protocol should call ``setNeedsEnvironmentUpdate()`` on
    ///   all `environmentDescendants` (which is behind the `ViewEnvironmentWiring` SPI namespace).
    ///
    func setNeedsEnvironmentUpdate()

    /// The `ViewEnvironment` propagation ancestor.
    ///
    /// This describes the ancestor that the `ViewEnvironment` is inherited from.
    ///
    /// To override the return value of this property for `UIViewController`/`UIView` subclasses, set the
    /// ``ViewEnvironmentPropagatingObject/environmentAncestorOverride`` property.  If no override is present, the
    /// return value will be `parent ?? presentingViewController`/`superview`.
    ///
    /// If the value of the ancestor is `nil`, by default, ancestors will not notify this node of needing an
    /// environment update as it changes. This allows a node to effectively detach from its ancestor and act as a root
    /// node when needed, without any changes to the ancestor (e.g. bridging from other propagation systems like
    /// WorkflowUI).
    ///
    @_spi(ViewEnvironmentWiring)
    var environmentAncestor: ViewEnvironmentPropagating? { get }

    /// The [`ViewEnvironment` propagation](x-source-tag://ViewEnvironmentObserving)
    /// descendants.
    ///
    /// This describes the descendants that will be notified when the `ViewEnvironment` changes.
    ///
    /// To override the return value of this property for `UIViewController`/`UIView` subclasses, set the
    /// ``ViewEnvironmentPropagatingObject/environmentDescendantsOverride`` property.  If no override is present, the
    /// return value will be a collection of all `children` in  addition to the `presentedViewController` for
    /// `UIViewController`s and `subviews` for `UIView`s.
    ///
    @_spi(ViewEnvironmentWiring)
    var environmentDescendants: [ViewEnvironmentPropagating] { get }
}

extension ViewEnvironmentPropagating {
    /// The `ViewEnvironment` that is flowing through the propagation hierarchy.
    ///
    /// If you'd like to provide overrides for the environment as it flows through a node, you should conform to
    /// `ViewEnvironmentObserving` and provide those overrides in `customize(environment:)`. E.g.:
    /// ```swift
    /// func customize(environment: inout ViewEnvironment) {
    ///     environment.traits.mode = .dark
    /// }
    /// ```
    ///
    /// By default, this property gets the environment by recursively walking to the root of the
    /// propagation path, and applying customizations on the way back down. The invalidation path may be
    /// interrupted if a node has set it's `environmentAncestor` to `nil`, even if there is a node
    /// which specifies this node as an `environmentDescendant`.
    ///
    /// If you'd like to update the return value of this variable and have those changes propagated through the
    /// propagation hierarchy, conform to `ViewEnvironmentObserving` and call ``setNeedsEnvironmentUpdate()`` and wait
    /// for the system to call `apply(context:)` when appropriate (e.g. on the next layout pass for
    /// `UIViewController`/`UIView` subclasses).
    ///
    /// - Important: `UIViewController` and `UIView` conformers _must_ call
    /// ``ViewEnvironmentObserving/applyEnvironmentIfNeeded()-8gr5k`` in `viewWillLayoutSubviews()` and
    /// `layoutSubviews()` respectively.
    ///
    public var environment: ViewEnvironment {
        var environment = environmentAncestor?.environment ?? .empty

        if let observing = self as? ViewEnvironmentObserving {
            observing.customize(environment: &environment)
        }

        return environment
    }

    /// Notifies all appropriate descendants that the environment needs update.
    ///
    /// Ancestor-descendent bindings must be mutually agreed for this method to notify them. If a descendant's ancestor
    /// is `nil` it will not be notified of needing update.
    ///
    @_spi(ViewEnvironmentWiring)
    public func setNeedsEnvironmentUpdateOnAppropriateDescendants() {
        for descendant in environmentDescendants {
            // If the descendant's ancestor is nil it has opted out of environment updates and is likely acting as
            // a root for propagation bridging purposes (e.g. from a Workflow ViewEnvironment update).
            // Avoid updating the descendant if this is the case.
            guard descendant.environmentAncestor != nil else {
                continue
            }

            descendant.setNeedsEnvironmentUpdate()
        }
    }
}

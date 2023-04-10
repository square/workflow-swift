/*
 * Copyright 2022 Square Inc.
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
    /// - Tag: ViewEnvironmentObserving.setNeedsEnvironmentUpdate
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
    /// propagation path, and applying customizations on the way back down. You may override this
    /// property instead if you want to completely interrupt the propagation flow and replace the
    /// environment. You can get the default value that would normally be propagated by calling
    /// `_defaultViewEnvironment`.
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
    @_spi(ViewEnvironmentWiring)
    var environment: ViewEnvironment { get }
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
    /// propagation path, and applying customizations on the way back down. You may override this
    /// property instead if you want to completely interrupt the propagation flow and replace the
    /// environment. You can get the default value that would normally be propagated by calling
    /// `_defaultViewEnvironment`.
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
        _defaultViewEnvironment
    }

    /// The default `ViewEnvironment` returned by ``environment``.
    ///
    /// The environment is constructed by recursively walking to the root of the propagation path
    /// and then applying all customizations on the way back down.
    ///
    ///  You should only need to access this value if you are overriding ``environment``
    /// and want to conditionally return the default.
    @_spi(ViewEnvironmentWiring)
    public var _defaultViewEnvironment: ViewEnvironment {
        var environment = environmentAncestor?.environment
            ?? .empty

        (self as? ViewEnvironmentCustomizing)?.customize(environment: &environment)

        return environment
    }

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

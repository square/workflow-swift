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
public protocol ViewEnvironmentObserving: ViewEnvironmentPropagating {
    /// Customizes the `ViewEnvironment` as it flows through this propagation node to provide overrides to environment
    /// values. These changes will be propagated to all descendant nodes.
    ///
    /// If you'd like to just inherit the environment from above, leave this function body empty.
    ///
    /// - Important: `UIViewController` and `UIView` conformers _must_ call
    ///   ``ViewEnvironmentObserving/applyEnvironmentIfNeeded()-8gr5k``in `viewWillLayoutSubviews()` and
    ///   `layoutSubviews()` respectively.
    ///
    func customize(environment: inout ViewEnvironment)

    /// Consumers should apply the `ViewEnvironment` to their node when this function is called.
    ///
    /// - Important: `UIViewController` and `UIView` conformers _must_ call ``applyEnvironmentIfNeeded()-3bamq``
    ///   in `viewWillLayoutSubviews()` and `layoutSubviews()` respectively.
    ///
    func apply(environment: ViewEnvironment)

    /// Consumers _must_ call this function when the environment should be re-applied, e.g. in
    /// `viewWillLayoutSubviews()` for `UIViewController`s and `layoutSubviews()` for `UIView`s.
    ///
    /// This will call ``apply(environment:)`` on the receiver if the node has been flagged for needing update.
    ///
    /// - Tag: ViewEnvironmentObserving.applyEnvironmentIfNeeded
    ///
    func applyEnvironmentIfNeeded()

    /// Called when the environment has been set for needing update, but before it has been applied.
    ///
    /// This may be called frequently when compared to ``apply(environment:)`` which should only be called
    /// when it's appropriate to apply the environment to the backing object (e.g. `viewWillLayoutSubviews`).
    ///
    func environmentDidChange()
}

extension ViewEnvironmentObserving {
    public func customize(environment: inout ViewEnvironment) {}

    public func apply(environment: ViewEnvironment) {}

    public func environmentDidChange() {}
}

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

/// `ViewEnvironmentObserving` allows an environment propagation node to observe updates to the
/// `ViewEnvironment` as it flows through the node hierarchy and have
/// the environment applied to the node.
///
/// For example, for a `UIViewController` hierarchy observing `ViewEnvironment`:
/// ```swift
/// final class MyViewController:
///     UIViewController, ViewEnvironmentObserving
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
/// - Tag: ViewEnvironmentObserving
///
public protocol ViewEnvironmentObserving: ViewEnvironmentCustomizing {
    /// Consumers should apply the `ViewEnvironment` to their node when this function is called.
    ///
    /// - Important: `UIViewController` and `UIView` conformers _must_ call ``applyEnvironmentIfNeeded()-3bamq``
    ///   in `viewWillLayoutSubviews()` and `layoutSubviews()` respectively.
    ///
    func apply(environment: ViewEnvironment)

    /// Consumers _must_ call this function when the envirnoment should be re-applied, e.g. in
    /// `viewWillLayoutSubviews()` for `UIViewController`s and `layoutSubviews()` for `UIView`s.
    ///
    /// This will call ``apply(environment:)`` on the receiver if the node has been flagged for needing update.
    ///
    /// - Tag: ViewEnvironmentObserving.applyEnvironmentIfNeeded
    ///
    func applyEnvironmentIfNeeded()
}

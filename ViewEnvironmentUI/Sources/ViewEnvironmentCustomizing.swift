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

public protocol ViewEnvironmentCustomizing: ViewEnvironmentPropagating {
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
}

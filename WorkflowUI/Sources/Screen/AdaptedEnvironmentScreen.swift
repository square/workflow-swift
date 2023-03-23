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

#if canImport(UIKit)

import Foundation
import ViewEnvironment

/// Wraps a `Screen` tree with a modified `ViewEnvironment`.
///
/// By specifying environmental values with this `Screen`, all child screens nested
/// will inherit those values automatically. Values can be changed
/// anywhere in a sub-tree by inserting another `AdaptedEnvironmentScreen`.
///
/// ```swift
/// MyScreen(...)
///     .adaptedEnvironment(keyPath: \.myValue, to: newValue)
/// ```
///
public struct AdaptedEnvironmentScreen<Content> {
    /// The screen wrapped by this screen.
    public var wrapped: Content

    /// Takes in a mutable `ViewEnvironment` which can be mutated to add or override values.
    public typealias Adapter = (inout ViewEnvironment) -> Void

    var adapter: Adapter

    /// Wraps a `Screen` with an environment that is modified using the given configuration block.
    ///
    /// - Parameters:
    ///   - wrapping: The screen to be wrapped.
    ///   - adapting: A block that will set environmental values.
    public init(
        wrapping wrapped: Content,
        adapting: @escaping Adapter
    ) {
        self.wrapped = wrapped
        self.adapter = adapting
    }

    /// Wraps a `Screen` with an environment that is modified for a single key and value.
    ///
    /// - Parameters:
    ///   - wrapping: The screen to be wrapped.
    ///   - key: The environment key to modify.
    ///   - value: The new environment value to cascade.
    public init<Key: ViewEnvironmentKey>(
        wrapping screen: Content,
        key: Key.Type,
        value: Key.Value
    ) {
        self.init(wrapping: screen, adapting: { $0[key] = value })
    }

    /// Wraps a `Screen` with an environment that is modified for a single value.
    ///
    /// - Parameters:
    ///   - wrapping: The screen to be wrapped.
    ///   - keyPath: The keypath of the environment value to modify.
    ///   - value: The new environment value to cascade.
    public init<Value>(
        wrapping screen: Content,
        keyPath: WritableKeyPath<ViewEnvironment, Value>,
        value: Value
    ) {
        self.init(wrapping: screen, adapting: { $0[keyPath: keyPath] = value })
    }
}

extension AdaptedEnvironmentScreen: Screen where Content: Screen {
    public func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
        var environment = environment

        adapter(&environment)

        return wrapped.viewControllerDescription(environment: environment)
    }
}

extension Screen {
    /// Wraps this screen in an `AdaptedEnvironmentScreen` with the given environment key and value.
    public func adaptedEnvironment<Key: ViewEnvironmentKey>(
        key: Key.Type,
        value: Key.Value
    ) -> AdaptedEnvironmentScreen<Self> {
        AdaptedEnvironmentScreen(wrapping: self, key: key, value: value)
    }

    /// Wraps this screen in an `AdaptedEnvironmentScreen` with the given keypath and value.
    func adaptedEnvironment<Value>(
        keyPath: WritableKeyPath<ViewEnvironment, Value>,
        value: Value
    ) -> AdaptedEnvironmentScreen<Self> {
        AdaptedEnvironmentScreen(wrapping: self, keyPath: keyPath, value: value)
    }

    /// Wraps this screen in an `AdaptedEnvironmentScreen` with the given configuration block.
    func adaptedEnvironment(
        adapting: @escaping (inout ViewEnvironment) -> Void
    ) -> AdaptedEnvironmentScreen<Self> {
        AdaptedEnvironmentScreen(wrapping: self, adapting: adapting)
    }
}

#endif

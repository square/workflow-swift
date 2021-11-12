/*
 * Copyright 2021 Square Inc.
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

    extension Screen {
        /// Sets the view environment value for the given key path to a specific value.
        ///
        /// - Parameters:
        ///   - keyPath: The key path to a property of `ViewEnvironment` to modify
        ///   - value: The value to set for the environment property specified by `keyPath`
        /// - Returns: A screen that has the given value set on its view environment
        public func environment<Value>(_ keyPath: WritableKeyPath<ViewEnvironment, Value>, _ value: Value) -> EnvironmentScreen<Self> {
            transformEnvironment(keyPath) { environmentValue in
                environmentValue = value
            }
        }

        /// Transforms the view environment value for the given key path with the given function.
        ///
        /// - Parameters:
        ///   - keyPath: The key path to a property of `ViewEnvironment` to modify
        ///   - transform: The transformation to apply to the environment property specified by `keyPath`
        /// - Returns: A screen that has the given transformation applied to its view environment
        public func transformEnvironment<Value>(_ keyPath: WritableKeyPath<ViewEnvironment, Value>, transform: @escaping (inout Value) -> Void) -> EnvironmentScreen<Self> {
            return transformEnvironment { environment in
                transform(&environment[keyPath: keyPath])
            }
        }

        /// Transforms the view environment with the given function.
        ///
        /// - Parameters:
        ///   - transform: The transformation to apply to the environment
        /// - Returns: A screen that has the given transformation applied to its view environment
        public func transformEnvironment(_ transform: @escaping (inout ViewEnvironment) -> Void) -> EnvironmentScreen<Self> {
            return EnvironmentScreen(content: self, transform: transform)
        }
    }

#endif

/// A wrapper screen around `Content` that modifies the environment of the contained content.
///
/// See `environment(_:_:)`, `transformEnvironment(_:_)` or `transformEnvironment(_:)`
/// to construct an `EnvironmentScreen`.
public struct EnvironmentScreen<Content> {
    public var content: Content

    var transform: (inout ViewEnvironment) -> Void

    init(content: Content, transform: @escaping (inout ViewEnvironment) -> Void) {
        self.content = content
        self.transform = transform
    }
}

#if canImport(UIKit)

    extension EnvironmentScreen: Screen where Content: Screen {
        public func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
            var modifiedEnvironment = environment
            transform(&modifiedEnvironment)
            return content.viewControllerDescription(environment: modifiedEnvironment)
        }
    }

#endif

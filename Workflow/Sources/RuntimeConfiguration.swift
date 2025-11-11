/*
 * Copyright Square Inc.
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

/// System for managing configuration options for Workflow runtime behaviors.
/// - important: These interfaces are subject to breaking changes without corresponding semantic
/// versioning changes.
@_spi(WorkflowRuntimeConfig)
public enum Runtime {
    @TaskLocal
    static var _currentConfiguration: Configuration?

    /// Update the base configuration used by the workflow runtime when creating
    /// new `WorkflowHost` instances.
    /// - Note: Updating this does not affect the existing configuration values used by
    /// extant `WorkflowHost` instances.
    ///
    /// - Parameter configuration: The runtime configuration to use.
    @MainActor
    public static func updateDefaultConfiguration(
        _ configureBlock: (inout Configuration) -> Void
    ) {
        MainActor.preconditionIsolated(
            "Must be called from the main actor."
        )

        var config = Configuration()
        configureBlock(&config)
        _defaultConfiguration = config
    }

    private static var _defaultConfiguration = Configuration()

    static var configuration: Configuration {
        _currentConfiguration ?? _defaultConfiguration
    }

    /// Allows temporary customization of the runtime configuration during the execution of the `operation`.
    ///
    /// - Parameters:
    ///   - override: An option block to reconfigure the current configuration value.
    ///   - operation: The operation to perform with the customized configuration.
    public static func withConfiguration<T>(
        override: ((inout Configuration) -> Void)? = nil,
        operation: () -> T
    ) -> T {
        var configSnapshot = configuration
        override?(&configSnapshot)

        return Runtime
            .$_currentConfiguration
            .withValue(
                configSnapshot,
                operation: operation
            )
    }
}

extension Runtime {
    /// Configuration options for the Workflow runtime.
    public struct Configuration: Equatable {
        /// The default runtime configuration.
        static let `default` = Configuration()

        /// Note: this doesn't control anything yet, but is here as a placeholder
        public var renderOnlyIfStateChanged: Bool = false

        /// Whether action handling should be delegated to the `SinkEventHandler` type.
        /// This is expected to eventually be removed and become the default behavior.
        public var useSinkEventHandler: Bool = false
    }
}

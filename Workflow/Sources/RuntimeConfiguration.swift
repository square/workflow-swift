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

    static var _bootstrapConfiguration = BootstrappableConfiguration()

    /// Bootstrap the workflow runtime with the given configuration.
    /// This can only be called once per process and must be called from the main thread.
    ///
    /// - Parameter configuration: The runtime configuration to use.
    @MainActor
    public static func bootstrap(
        _ configureBlock: (inout Configuration) -> Void
    ) {
        MainActor.preconditionIsolated(
            "The Workflow runtime must be bootstrapped from the main actor."
        )
        guard !_isBootstrapped else {
            fatalError("The Workflow runtime can only be bootstrapped once.")
        }

        var config = _bootstrapConfiguration.currentConfiguration
        configureBlock(&config)
        _bootstrapConfiguration._bootstrapConfig = config
    }

    static var configuration: Configuration {
        _currentConfiguration ?? _bootstrapConfiguration.currentConfiguration
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

    // MARK: -

    private static var _isBootstrapped: Bool {
        _bootstrapConfiguration._bootstrapConfig != nil
    }

    /// The current runtime configuration that may have been set via `bootstrap()`.
    private static var _currentBootstrapConfiguration: Configuration {
        _bootstrapConfiguration.currentConfiguration
    }
}

extension Runtime {
    /// Configuration options for the Workflow runtime.
    public struct Configuration: Equatable {
        /// The default runtime configuration.
        static let `default` = Configuration()

        /// Note: this doesn't control anything yet, but is here as a placeholder
        public var renderOnlyIfStateChanged: Bool = false
    }

    struct BootstrappableConfiguration {
        var _bootstrapConfig: Configuration?
        let _defaultConfig: Configuration = .default

        /// The current runtime configuration that may have been set via `Runtime.bootstrap()`.
        var currentConfiguration: Configuration {
            _bootstrapConfig ?? _defaultConfig
        }
    }
}

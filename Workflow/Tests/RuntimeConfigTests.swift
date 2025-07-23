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

import Testing

@_spi(WorkflowRuntimeConfig) @testable import Workflow

@MainActor
struct RuntimeConfigTests {
    @Test
    private func runtime_config_inits_to_default() {
        let cfg = Runtime.Configuration()
        #expect(cfg == Runtime.Configuration.default)
    }

    @Test
    private func test_global_config_defaults_to_default() {
        #expect(Runtime.configuration == .default)
    }

    @Test
    private func runtime_config_prefers_bootstrap_value() {
        #expect(Runtime.configuration.renderOnlyIfStateChanged == false)

        defer {
            // reset global state...
            Runtime.resetConfig()
        }
        Runtime.bootstrap { cfg in
            cfg.renderOnlyIfStateChanged = true
        }

        #expect(Runtime.configuration.renderOnlyIfStateChanged == true)
    }

    @Test
    private func test_config_respects_task_local_overrides() {
        var customConfig = Runtime.configuration
        customConfig.renderOnlyIfStateChanged = true

        Runtime.$_currentConfiguration.withValue(customConfig) {
            #expect(Runtime.configuration.renderOnlyIfStateChanged == true)
        }
    }

    @Test
    private func test_withConfiguration() {
        #expect(Runtime.configuration.renderOnlyIfStateChanged == false)

        var override = Runtime.configuration
        override.renderOnlyIfStateChanged = true

        let newValue = Runtime.$_currentConfiguration.withValue(override) {
            Runtime.withConfiguration {
                Runtime.configuration.renderOnlyIfStateChanged
            }
        }
        #expect(newValue == true)
    }

    @Test
    private func test_withConfigurationOverride() {
        let newValue = Runtime.withConfiguration(
            override: { cfg in
                #expect(Runtime.configuration.renderOnlyIfStateChanged == false)
                #expect(cfg.renderOnlyIfStateChanged == false)
                cfg.renderOnlyIfStateChanged = true
            },
            operation: {
                Runtime.configuration.renderOnlyIfStateChanged
            }
        )

        #expect(newValue == true)
    }
}

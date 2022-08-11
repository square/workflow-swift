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

#if canImport(SwiftUI)

    import SwiftUI
    import WorkflowUI

    private struct ViewEnvironmentKey: EnvironmentKey {
        static let defaultValue: ViewEnvironment = .empty
    }

    @available(iOS 13.0, macOS 10.15, *)
    public extension EnvironmentValues {
        var viewEnvironment: ViewEnvironment {
            get { self[ViewEnvironmentKey.self] }
            set { self[ViewEnvironmentKey.self] = newValue }
        }
    }

#endif

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

#if canImport(SwiftUI)

import SwiftUI

extension EnvironmentValues {
    public var viewEnvironment: ViewEnvironment {
        get { self[ViewEnvironmentKey.self] }
        set { self[ViewEnvironmentKey.self] = newValue }
    }

    private struct ViewEnvironmentKey: EnvironmentKey {
        static let defaultValue: ViewEnvironment = .empty
    }
}


extension Environment where Value == ViewEnvironment {
    
    @available(
        *,
         deprecated,
         message:
            """
            Please do not create an `@Environment` property that references the top-level `viewEnvironment`: \
            it will break SwiftUI's automatic invalidation when any part of the `ViewEnvironment` changes. \
            Instead, reference your relevant sub-property, eg `@Environment(\\.viewEnvironment.myProperty)`.
            """
    )
    @inlinable public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {
        fatalError(
            """
            Please do not create an `@Environment` property that references the top-level `viewEnvironment`: \
            it will break SwiftUI's automatic invalidation when any part of the `ViewEnvironment` changes. \
            Instead, reference your relevant sub-property, eg `@Environment(\\.viewEnvironment.myProperty)`.
            """
        )
    }
}

#endif

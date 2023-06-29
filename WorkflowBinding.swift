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

import SwiftUI

@propertyWrapper public struct WorkflowBinding<Value> {
    public let wrappedValue: Value
    public let set: (Value) -> Void

    public init(value: Value, set: @escaping (Value) -> Void) {
        self.wrappedValue = value
        self.set = set
    }

    public var projectedValue: Binding<Value> {
        Binding(
            get: { wrappedValue },
            set: set
        )
    }
}

extension WorkflowBinding: Equatable where Value: Equatable {
    public static func == (lhs: WorkflowBinding<Value>, rhs: WorkflowBinding<Value>) -> Bool {
        // TODO: Don't assume setters are equivalent. Use some kind of binding identity?
        lhs.wrappedValue == rhs.wrappedValue
    }
}

extension WorkflowBinding: ExpressibleByUnicodeScalarLiteral where Value == String {}

extension WorkflowBinding: ExpressibleByExtendedGraphemeClusterLiteral where Value == String {}

extension WorkflowBinding: ExpressibleByStringLiteral where Value == String {
    public init(stringLiteral value: String) {
        self.init(value: value, set: { _ in })
    }
}

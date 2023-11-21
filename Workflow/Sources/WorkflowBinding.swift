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
    private let binding: Binding<Value>

    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        self.binding = Binding(get: get, set: set)
    }

    public init(_ binding: Binding<Value>) {
        self.binding = binding
    }

    public var wrappedValue: Value {
        get { binding.wrappedValue }
        set { binding.wrappedValue = newValue }
    }

    public var projectedValue: Binding<Value> {
        binding
    }
}

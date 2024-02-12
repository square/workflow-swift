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

import SwiftUI

public extension ObservableObjectValue {
    func binding<T>(
        get: @escaping (Value) -> T,
        set: @escaping (Value) -> (T) -> Void
    ) -> Binding<T> {
        // This convoluted way of creating a `Binding`, relative to `Binding.init(get:set:)`, is
        // a workaround borrowed from TCA for a SwiftUI issue:
        // https://github.com/pointfreeco/swift-composable-architecture/pull/770
        ObservedObject(wrappedValue: self)
            .projectedValue[get: .init(rawValue: get), set: .init(rawValue: set)]
    }

    private subscript<T>(
        get get: HashableWrapper<(Value) -> T>,
        set set: HashableWrapper<(Value) -> (T) -> Void>
    ) -> T {
        get { get.rawValue(value) }
        set { set.rawValue(value)(newValue) }
    }

    private struct HashableWrapper<Value>: Hashable {
        let rawValue: Value
        static func == (lhs: Self, rhs: Self) -> Bool { false }
        func hash(into hasher: inout Hasher) {}
    }
}

#endif

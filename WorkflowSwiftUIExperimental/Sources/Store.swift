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

@dynamicMemberLookup
public protocol Store<Value>: ObservableObject {
    associatedtype Value

    var value: Value { get }

    /// Returns the value at the given keypath of ``Value``.
    ///
    /// In combination with `@dynamicMemberLookup`, this allows us to write `model.myProperty` instead of
    /// `model.value.myProperty` where `model` conforms to `Store<T>`.
    subscript<T>(dynamicMember keyPath: KeyPath<Value, T>) -> T { get }
}

public extension Store {
    subscript<T>(dynamicMember keyPath: KeyPath<Value, T>) -> T {
        value[keyPath: keyPath]
    }
}

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

import Combine
import Workflow

@dynamicMemberLookup
public final class ObservableValue<Value>: ObservableObject {
    private var internalValue: Value
    private let subject = PassthroughSubject<Value, Never>()
    private var cancellable: AnyCancellable?

    public var value: Value {
        internalValue
    }

    public private(set) lazy var objectWillChange = ObservableObjectPublisher()

    public static func makeObservableValue(
        _ value: Value,
        isDuplicate: ((Value, Value) -> Bool)? = nil
    ) -> (ObservableValue, Sink<Value>) {
        let observableValue = ObservableValue(value: value, isDuplicate: isDuplicate)
        let sink = Sink(observableValue.subject.send(_:))
        return (observableValue, sink)
    }

    private init(value: Value, isDuplicate: ((Value, Value) -> Bool)?) {
        self.internalValue = value
        self.cancellable = subject
            .eraseToAnyPublisher()
            .dropFirst()
            .sink { [weak self] newValue in
                guard let self = self else { return }
                self.objectWillChange.send()
                self.internalValue = newValue
            }
    }

    // MARK: @dynamicMemberLookup

    /// Returns the value at the given keypath of ``Value``.
    ///
    /// In combination with `@dynamicMemberLookup`, this allows us to write `model.myProperty` instead of
    /// `model.value.myProperty` where `model` has type `ObservableValue<T>`.
    public subscript<T>(dynamicMember keyPath: KeyPath<Value, T>) -> T {
        internalValue[keyPath: keyPath]
    }
}

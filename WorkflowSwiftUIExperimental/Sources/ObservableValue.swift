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

public final class ObservableValue<Value>: Store {
    private var internalValue: Value
    private let subject = PassthroughSubject<Value, Never>()
    private var cancellable: AnyCancellable?
    private var isDuplicate: ((Value, Value) -> Bool)?

    public private(set) var value: Value {
        get {
            internalValue
        }
        set {
            subject.send(newValue)
        }
    }

    public private(set) lazy var objectWillChange = ObservableObjectPublisher()
    private var parentCancellable: AnyCancellable?

    public static func makeObservableValue(
        _ value: Value,
        isDuplicate: ((Value, Value) -> Bool)? = nil
    ) -> (ObservableValue, Sink<Value>) {
        let observableValue = ObservableValue(value: value, isDuplicate: isDuplicate)
        let sink = Sink { newValue in
            observableValue.value = newValue
        }

        return (observableValue, sink)
    }

    private init(value: Value, isDuplicate: ((Value, Value) -> Bool)?) {
        self.internalValue = value
        self.isDuplicate = isDuplicate
        self.cancellable = valuePublisher()
            .dropFirst()
            .sink { [weak self] newValue in
                guard let self = self else { return }
                self.objectWillChange.send()
                self.internalValue = newValue
            }
        // Allows removeDuplicates operator to have the initial value.
        subject.send(value)
    }

    //// Scopes the ObservableValue to a subset of Value to LocalValue given the supplied closure while allowing to optionally remove duplicates.
    /// - Parameters:
    ///   - toLocalValue: A closure that takes a Value and returns a LocalValue.
    ///   - isDuplicate: An optional closure that checks to see if a LocalValue is a duplicate.
    /// - Returns: a scoped ObservableValue of LocalValue.
    public func scope<LocalValue>(_ toLocalValue: @escaping (Value) -> LocalValue, isDuplicate: ((LocalValue, LocalValue) -> Bool)? = nil) -> ObservableValue<LocalValue> {
        return scopeToLocalValue(toLocalValue, isDuplicate: isDuplicate)
    }

    /// Scopes the ObservableValue to a subset of Value to LocalValue given the supplied closure and removes duplicate values using Equatable.
    /// - Parameter toLocalValue: A closure that takes a Value and returns a LocalValue.
    /// - Returns: a scoped ObservableValue of LocalValue.
    public func scope<LocalValue>(_ toLocalValue: @escaping (Value) -> LocalValue) -> ObservableValue<LocalValue> where LocalValue: Equatable {
        return scopeToLocalValue(toLocalValue, isDuplicate: { $0 == $1 })
    }

    private func scopeToLocalValue<LocalValue>(_ toLocalValue: @escaping (Value) -> LocalValue, isDuplicate: ((LocalValue, LocalValue) -> Bool)? = nil) -> ObservableValue<LocalValue> {
        let localObservableValue = ObservableValue<LocalValue>(
            value: toLocalValue(internalValue),
            isDuplicate: isDuplicate
        )
        localObservableValue.parentCancellable = valuePublisher().sink(receiveValue: { newValue in
            localObservableValue.value = toLocalValue(newValue)
        })
        return localObservableValue
    }

    private func valuePublisher() -> AnyPublisher<Value, Never> {
        guard let isDuplicate = isDuplicate else {
            return subject.eraseToAnyPublisher()
        }

        return subject.removeDuplicates(by: isDuplicate).eraseToAnyPublisher()
    }
}

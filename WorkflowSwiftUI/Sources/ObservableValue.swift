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

#if canImport(SwiftUI) && canImport(Combine) && swift(>=5.1)

    import Combine
    import SwiftUI
    import Workflow

    @available(iOS 13.0, macOS 10.15, *)
    @dynamicMemberLookup
    public final class ObservableValue<Value>: ObservableObject {
        private var internalValue: Value
        private let subject = PassthroughSubject<Value, Never>()
        private var cancellable: AnyCancellable?
        private var isDuplicate: ((Value, Value) -> Bool)?
        public private(set) var value: Value {
            get {
                return internalValue
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

        private init(value: Value, isDuplicate: ((Value, Value) -> Bool)? = nil) {
            self.internalValue = value
            self.isDuplicate = isDuplicate
            self.cancellable = valuePublisher()
                .sink { [weak self] newValue in
                    guard let self = self else { return }
                    self.objectWillChange.send()
                    self.internalValue = newValue
                }
        }

        public func scope<LocalValue>(_ toLocalValue: @escaping (Value) -> LocalValue, isDuplicate: ((LocalValue, LocalValue) -> Bool)? = nil) -> ObservableValue<LocalValue> {
            return scopeToLocalValue(toLocalValue, isDuplicate: isDuplicate)
        }

        public func scope<LocalValue>(_ toLocalValue: @escaping (Value) -> LocalValue) -> ObservableValue<LocalValue> where LocalValue: Equatable {
            return scopeToLocalValue(toLocalValue, isDuplicate: { $0 == $1 })
        }

        /// Returns the value at the given keypath of ``Value``.
        ///
        /// In combination with `@dynamicMemberLookup`, this allows us to write `model.myProperty` instead of
        /// `model.value.myProperty` where `model` has type `ObservableValue<T>`.
        public subscript<T>(dynamicMember keyPath: KeyPath<Value, T>) -> T {
            internalValue[keyPath: keyPath]
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

    @available(iOS 13.0, macOS 10.15, *)
    public extension ObservableValue {
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

import SwiftUI
import Workflow

#if canImport(Observation)
    import Observation

@available(iOS 17, macOS 14.0, *)
@dynamicMemberLookup
@Observable public final class ObservableValue<Value> {
    private var internalValue: Value? = nil
    private var isDuplicate: ((Value, Value) -> Bool)? = nil
    public private(set) var value: Value {
        get {
            internalValue!
        }
        set {
            if let isDuplicate = isDuplicate, isDuplicate(internalValue!, newValue) {
                return
            }
            internalValue = newValue
        }
    }
    private init(value: Value, isDuplicate: ((Value, Value) -> Bool)?) {
        self.internalValue = value
        self.isDuplicate = isDuplicate
    }
    
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
    
    /// Returns the value at the given keypath of ``Value``.
    ///
    /// In combination with `@dynamicMemberLookup`, this allows us to write `model.myProperty` instead of
    /// `model.value.myProperty` where `model` has type `ObservableValue<T>`.
    public subscript<T>(dynamicMember keyPath: KeyPath<Value, T>) -> T {
        value[keyPath: keyPath]
    }
    
    public func scope<LocalValue>(_ toLocalValue: @escaping (Value) -> LocalValue, isDuplicate: ((LocalValue, LocalValue) -> Bool)? = nil) -> ObservableValue<LocalValue> {
        let localObservableValue = ObservableValue<LocalValue>(
            value: toLocalValue(value),
            isDuplicate: isDuplicate
        )
        withObservationTracking {
            let _ = toLocalValue(value)
        } onChange: { [weak self] in
            guard let self = self else { return }
            localObservableValue.value = toLocalValue(self.value)
        }

        return localObservableValue
    }
    
    public func scope<LocalValue>(_ toLocalValue: @escaping (Value) -> LocalValue) -> ObservableValue<LocalValue> where LocalValue: Equatable {
        return scope(toLocalValue, isDuplicate: { $0 == $1 })
    }
}
#endif

import SwiftUI

#if canImport(Observation)

@available(iOS 17, macOS 14.0, *)
public extension ObservableValue {
    func binding<T>(
        get: @escaping (Value) -> T,
        set: @escaping (Value) -> (T) -> Void
    ) -> Binding<T> {
        Bindable(wrappedValue: self)
            .projectedValue[get: .init(rawValue: get), set: .init(rawValue: set)]
    }

    private subscript<T>(
        get get: HashableWrapper<(Value) -> T>,
        set set: HashableWrapper<(Value) -> (T) -> Void>
    ) -> T {
        get { get.rawValue(value) }
        set { set.rawValue(value)(newValue) }
    }

    private struct HashableWrapper<RawValue>: Hashable {
        let rawValue: RawValue
        static func == (lhs: Self, rhs: Self) -> Bool { false }
        func hash(into hasher: inout Hasher) {}
    }
}
#endif

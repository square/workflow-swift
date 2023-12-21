// Copied from https://github.com/pointfreeco/swift-composable-architecture/blob/acfbab4290adda4e47026d059db36361958d495c/Sources/ComposableArchitecture/Observation/BindableStore.swift

import ComposableArchitecture
import SwiftUI

/// A property wrapper type that supports creating bindings to the mutable properties of a
/// ``Store``.
///
/// Use this property wrapper in iOS 16, macOS 13, tvOS 16, watchOS 9, and earlier, when `@Bindable`
/// is unavailable, to derive bindings to properties of your features.
///
/// If you are targeting iOS 17, macOS 14, tvOS 17, watchOS 9, or later, then you can replace
/// ``BindableStore`` with SwiftUI's `@Bindable`.
@available(iOS, deprecated: 17, renamed: "Bindable")
@available(macOS, deprecated: 14, renamed: "Bindable")
@available(tvOS, deprecated: 17, renamed: "Bindable")
@available(watchOS, deprecated: 10, renamed: "Bindable")
@propertyWrapper
@dynamicMemberLookup
struct BindableStore<State: ObservableState, Action> {
    var wrappedValue: Store<State, Action>
    init(wrappedValue: Store<State, Action>) {
        self.wrappedValue = wrappedValue
    }

    var projectedValue: BindableStore<State, Action> {
        self
    }

    subscript<Subject>(
        dynamicMember keyPath: ReferenceWritableKeyPath<Store<State, Action>, Subject>
    ) -> Binding<Subject> {
        Binding(
            get: { self.wrappedValue[keyPath: keyPath] },
            set: { self.wrappedValue[keyPath: keyPath] = $0 }
        )
    }
}

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
//@available(iOS, deprecated: 17, renamed: "Bindable")
//@available(macOS, deprecated: 14, renamed: "Bindable")
//@available(tvOS, deprecated: 17, renamed: "Bindable")
//@available(watchOS, deprecated: 10, renamed: "Bindable")
//@propertyWrapper
//@dynamicMemberLookup
//struct BindableStore<Model: ObservableModel> {
//    var wrappedValue: Store<Model>
//    init(wrappedValue: Store<Model>) {
//        self.wrappedValue = wrappedValue
//    }
//
//    var projectedValue: Self {
//        self
//    }
//
//    subscript<Value>(
//        dynamicMember keyPath: ReferenceWritableKeyPath<Store<Model>, Value>
//    ) -> Binding<Value> {
//        wrappedValue.binding(for: keyPath)
//    }
//}

// TODO: can we use this instead of Perception.Bindable to re-introduce a cache on the root Binding?


// Copied from https://github.com/pointfreeco/swift-composable-architecture/blob/acfbab4290adda4e47026d059db36361958d495c/Sources/ComposableArchitecture/Observation/Binding%2BObservation.swift

import ComposableArchitecture
import SwiftUI

// NB: These overloads ensure runtime warnings aren't emitted for errant SwiftUI bindings.
#if DEBUG
extension Binding {
    public subscript<State: ObservableState, Member: Equatable>(
        dynamicMember keyPath: WritableKeyPath<State, Member>
    ) -> Binding<Member>
        where Value == Store<State> {
        Binding<Member>(
            get: { self.wrappedValue.state[keyPath: keyPath] },
            set: { _ in fatalError("TODO") }
        )
    }
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension Bindable {
    public subscript<State: ObservableState, Member: Equatable>(
        dynamicMember keyPath: WritableKeyPath<State, Member>
    ) -> Binding<Member>
        where Value == Store<State> {
        Binding<Member>(
            get: { self.wrappedValue.state[keyPath: keyPath] },
            set: { _ in fatalError("TODO") }
        )
    }
}

extension BindableStore {
    public subscript<Member: Equatable>(
        dynamicMember keyPath: WritableKeyPath<State, Member>
    ) -> Binding<Member> {
        Binding<Member>(
            get: { self.wrappedValue.state[keyPath: keyPath] },
            set: { _ in fatalError("TODO") }
        )
    }
}
#endif

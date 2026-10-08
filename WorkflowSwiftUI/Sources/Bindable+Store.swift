import CasePaths
import SwiftUI
import Workflow

extension SwiftUI.Bindable {
    @_disfavoredOverload
    public subscript<Model: ObservableModel, Member>(
        dynamicMember keyPath: KeyPath<Model.State, Member>
    ) -> _NativeStoreBindable<Model, Member>
        where Value == Store<Model>
    {
        _NativeStoreBindable(bindable: self, keyPath: keyPath)
    }
}

/// Provides custom action redirection for bindings derived from a Store.
@dynamicMemberLookup
public struct _NativeStoreBindable<Model: ObservableModel, Value> {
    fileprivate let bindable: SwiftUI.Bindable<Store<Model>>
    fileprivate let keyPath: KeyPath<Model.State, Value>

    public subscript<Member>(
        dynamicMember keyPath: KeyPath<Value, Member>
    ) -> _NativeStoreBindable<Model, Member> {
        _NativeStoreBindable<Model, Member>(
            bindable: bindable,
            keyPath: self.keyPath.appending(path: keyPath)
        )
    }

    /// Creates a binding to the value by sending new values through the given sink.
    public func sending<Action>(
        sink: KeyPath<Model, Sink<Action>>,
        action: CaseKeyPath<Action, Value>
    ) -> Binding<Value> {
        bindable[state: keyPath, sink: sink, action: action]
    }

    /// Creates a binding to the value by sending new values through a closure.
    public func sending(
        closure: KeyPath<Model, (Value) -> Void>
    ) -> Binding<Value> {
        bindable[state: keyPath, send: closure]
    }
}

extension _NativeStoreBindable where Model: SingleActionModel {
    /// Creates a binding to the value by sending new values through the model's action.
    public func sending(
        action: CaseKeyPath<Model.Action, Value>
    ) -> Binding<Value> {
        bindable[state: keyPath, action: action]
    }
}

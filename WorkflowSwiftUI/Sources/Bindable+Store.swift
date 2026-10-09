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
///
/// ## Example
///
/// To update state through a custom action, make the action `CasePathable` and append
/// `sending(action:)` to the binding.
///
/// ```swift
/// import CasePaths
/// import SwiftUI
/// import Workflow
/// import WorkflowSwiftUI
///
/// @ObservableState
/// public struct State {
///     var isOn = false
/// }
///
/// @CasePathable
/// public enum Action: WorkflowAction {
///     public typealias WorkflowType = MyWorkflow
///
///     case toggle(Bool)
///
///     public func apply(toState state: inout State) -> WorkflowType.Output? {
///         switch self {
///         case .toggle(let value):
///             state.isOn = value
///             return nil
///         }
///     }
/// }
///
/// public typealias MyModel = ActionModel<State, Action>
///
/// public struct MyWorkflow: Workflow {
///     public typealias Rendering = MyModel
///     public typealias Output = Never
///
///     public func makeInitialState() -> State {
///         .init()
///     }
///
///     public func render(state: State, context: RenderContext<MyWorkflow>) -> Rendering {
///         context.makeActionModel(state: state)
///     }
/// }
///
/// public struct MyWorkflowView: View {
///     @SwiftUI.Bindable var store: Store<MyWorkflow.Rendering>
///
///     public var body: some View {
///         Toggle(
///             "Enabled",
///             isOn: $store.isOn.sending(action: \.toggle)
///         )
///     }
/// }
/// ```
///
/// This type supports `sending` on a chained binding. You do not need to use it directly.
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
    ///
    /// - Parameter sink: A key path to the sink on the model.
    /// - Parameter action: The case key path for the action that contains the new value.
    /// - Returns: A binding.
    public func sending<Action>(
        sink: KeyPath<Model, Sink<Action>>,
        action: CaseKeyPath<Action, Value>
    ) -> Binding<Value> {
        bindable[state: keyPath, sink: sink, action: action]
    }

    /// Creates a binding to the value by sending new values through a closure.
    ///
    /// - Parameter closure: A key path to a closure on the model.
    /// - Returns: A binding.
    public func sending(
        closure: KeyPath<Model, (Value) -> Void>
    ) -> Binding<Value> {
        bindable[state: keyPath, send: closure]
    }
}

extension _NativeStoreBindable where Model: SingleActionModel {
    /// Creates a binding to the value by sending new values through the model's action.
    ///
    /// - Parameter action: The case key path for the action that contains the new value.
    /// - Returns: A binding.
    public func sending(
        action: CaseKeyPath<Model.Action, Value>
    ) -> Binding<Value> {
        bindable[state: keyPath, action: action]
    }
}

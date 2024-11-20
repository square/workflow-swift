import CasePaths
import Perception
import SwiftUI
import Workflow

extension Perception.Bindable {
    @_disfavoredOverload
    public subscript<Model: ObservableModel, Member>(
        dynamicMember keyPath: KeyPath<Model.State, Member>
    ) -> _StoreBindable<Model, Member>
        where Value == Store<Model>
    {
        _StoreBindable(bindable: self, keyPath: keyPath)
    }
}

/// Provides custom action redirection on bindings chained from the root model.
///
/// ## Example
///
/// In this example, the `State` type has a `Bool` we can bind to, but we want to use the custom
/// `Action` type to update instead.
///
/// We can achieve this by making the action `CasePathable` and then appending `sending(action:)` to
/// the binding.
///
/// ```swift
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
///         return context.makeActionModel(state: state)
///     }
/// }
///
/// public struct MyWorkflowView: View {
///     @Perception.Bindable var store: Store<MyWorkflow.Rendering>
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
/// This type is used internally when `sending` is used on a chained binding; you do not need to use
/// it directly.
@dynamicMemberLookup
public struct _StoreBindable<Model: ObservableModel, Value> {
    fileprivate let bindable: Perception.Bindable<Store<Model>>
    fileprivate let keyPath: KeyPath<Model.State, Value>

    public subscript<Member>(
        dynamicMember keyPath: KeyPath<Value, Member>
    ) -> _StoreBindable<Model, Member> {
        _StoreBindable<Model, Member>(
            bindable: bindable,
            keyPath: self.keyPath.appending(path: keyPath)
        )
    }

    /// Creates a binding to the value by sending new values through the given sink.
    ///
    /// - Parameter sink: The sink to receive an action with values from the binding.
    /// - Parameter action: An action to contain sent values.
    /// - Returns: A binding.
    public func sending<Action>(
        sink: KeyPath<Model, Sink<Action>>,
        action: CaseKeyPath<Action, Value>
    ) -> Binding<Value> {
        bindable[state: keyPath, sink: sink, action: action]
    }

    /// Creates a binding to the value by sending new values through a closure.
    ///
    /// - Parameter closure: A keypath to a closure on the model.
    /// - Returns: A binding.
    public func sending(
        closure: KeyPath<Model, (Value) -> Void>
    ) -> Binding<Value> {
        bindable[state: keyPath, send: closure]
    }
}

extension _StoreBindable where Model: SingleActionModel {
    /// Creates a binding to the value by sending new values through the model's action.
    ///
    /// - Parameter action: An action to contain sent values.
    /// - Returns: A binding.
    public func sending(
        action: CaseKeyPath<Model.Action, Value>
    ) -> Binding<Value> {
        bindable[state: keyPath, action: action]
    }
}

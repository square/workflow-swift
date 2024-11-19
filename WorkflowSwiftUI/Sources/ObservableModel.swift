import Workflow

/// A type that can be observed for fine-grained changes and accept updates.
///
/// Workflows that render ``ObservableModel`` types can be used to power ``ObservableScreen``
/// screens, for performant UI that only updates when necessary, while still adhering to a
/// unidirectional data flow.
///
/// To render an ``ObservableModel``, your Workflow state must first conform to ``ObservableState``,
/// using the `@ObservableState` macro.
///
/// # Examples
///
/// For trivial workflows with no actions, you can generate a model directly from your state:
///
/// ```swift
/// struct TrivialWorkflow: Workflow {
///     typealias Output = Never
///
///     @ObservableState
///     struct State {
///         var counter = 0
///     }
///
///     func makeInitialState() -> State {
///         .init()
///     }
///
///     func render(
///         state: State,
///         context: RenderContext<Self>
///     ) -> StateAccessor<State> {
///         context.makeStateAccessor(state: state)
///     }
/// }
/// ```
///
/// For simple workflows with a single action, you can generate a model from your state and action:
///
/// ```swift
/// struct SingleActionWorkflow: Workflow {
///     typealias Output = Never
///
///     @ObservableState
///     struct State {
///         var counter = 0
///     }
///
///     enum Action: WorkflowAction {
///         typealias WorkflowType = SingleActionWorkflow
///         case increment
///
///         func apply(toState state: inout State) -> Never? {
///             state.counter += 1
///             return nil
///         }
///     }
///
///     func makeInitialState() -> State {
///         .init()
///     }
///
///     func render(
///         state: State,
///         context: RenderContext<Self>
///     ) -> ActionModel<State, Action> {
///         context.makeActionModel(state: state)
///     }
/// }
/// ```
///
/// For complex workflows that have multiple actions or compose observable models from child
///    workflows, you can create a custom model that conforms to ``ObservableModel``:
///
/// ```swift
/// struct ComplexWorkflow: Workflow {
///     typealias Output = Never
///
///     @ObservableState
///     struct State {
///         var counter = 0
///     }
///
///     enum UpAction: WorkflowAction {
///         typealias WorkflowType = ComplexWorkflow
///         case increment
///
///         func apply(toState state: inout State) -> Never? {
///             state.counter += 1
///             return nil
///         }
///     }
///
///     enum DownAction: WorkflowAction {
///         typealias WorkflowType = ComplexWorkflow
///         case decrement
///
///         func apply(toState state: inout State) -> Never? {
///             state.counter -= 1
///             return nil
///         }
///     }
///
///     func makeInitialState() -> State {
///         .init()
///     }
///
///     func render(
///         state: State,
///         context: RenderContext<Self>
///     ) -> CustomModel {
///         CustomModel(
///             accessor: context.makeStateAccessor(state: state),
///             child: TrivialWorkflow().rendered(in: context),
///             up: context.makeSink(of: UpAction.self),
///             down: context.makeSink(of: DownAction.self)
///         )
///     }
/// }
///
/// struct CustomModel: ObservableModel {
///     var accessor: StateAccessor<ComplexWorkflow.State>
///
///     var child: TrivialWorkflow.Rendering
///
///     var up: Sink<ComplexWorkflow.UpAction>
///     var down: Sink<ComplexWorkflow.DownAction>
/// }
/// ```
///
@dynamicMemberLookup
public protocol ObservableModel<State> {
    /// The associated state type that this model observes.
    associatedtype State: ObservableState

    /// The accessor that can be used to read and write state.
    var accessor: StateAccessor<State> { get }
}

extension ObservableModel {
    /// Allows dynamic member lookup to read and write state through the accessor.
    public subscript<T>(dynamicMember keyPath: WritableKeyPath<State, T>) -> T {
        get {
            accessor.state[keyPath: keyPath]
        }
        set {
            accessor.sendValue { $0[keyPath: keyPath] = newValue }
        }
    }
}

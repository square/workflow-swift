# WorkflowSwiftUI Adoption Guide

`WorkflowSwiftUI` is designed with performance in mind. Instead of updating the entire UI on every render loop, `WorkflowSwiftUI` uses the [Perception](https://github.com/pointfreeco/swift-perception) framework (a backport of Apple's Observation), to detect the data that each view is dependent on, and to only re-evaluate those views when that data has changed.

In order to support this, `WorkflowSwiftUI` has some additional restrictions and subtle departures from practices you may be used to.

- Your *view* and *workflow* both have knowledge of *state* and *actions* (collectively, a “model”).
- Your workflow renders a *model* rather than a *screen*.
- We recommend defining your model, view, and screen independently, rather than nesting any of these types.

## State

Observation is used to detect when the data that views use has changed, and to re-evaluate only the views that are affected.

To achieve this, your workflow’s `State` type must be annotated with the `@ObservableState` macro. This macro adds observation hooks to each property, and also endows your state struct with a concept of identity. 

```swift
@ObservableState
public struct State {
  var foo: String
  var bar: Int
}
```

For an `ObservableState` type, creating a copy does not change the state’s identity in the copy. However, creating a new value by calling the initializer will result in a new identity.

If your state has nested types, you can annotate them with `@ObservableState` as well, for fine-grained observation of the properties of that type as well.

```swift
@ObservableState
public struct State {
  var detail: Detail
}

@ObservableState
public struct Detail {
  var name: String
  var age: Int
}
```

In this example, changes to `state.detail.name` do not affect views that only use `state.detail.age` , and vice-versa. Without annotating `Detail` as `@ObservableState`, any change to a property on `state.detail` will invalidate views using any other property.

## Rendering models

Your workflow should render a type conforming to `ObservableModel`. This provides your view with a way to read from state and send updates that follow Workflow’s unidirectional data flow.

```swift
public protocol ObservableModel<State> {
    /// The associated state type that this model observes.
    associatedtype State: ObservableState

    /// The accessor that can be used to read and write state.
    var accessor: StateAccessor<State> { get }
}
```

Some conveniences are available on the `RenderContext` to make it easy to create a model type.

For trivial workflows with no actions, you can generate a model directly from your state:

```swift
struct TrivialWorkflow: Workflow {
    typealias Output = Never

    @ObservableState
    struct State {
        var counter = 0
    }

    func makeInitialState() -> State {
        .init()
    }

    func render(
        state: State,
        context: RenderContext<Self>
    ) -> StateAccessor<State> {
        context.makeStateAccessor(state: state)
    }
}

```

For simple workflows with a single action, you can generate a model from your state and action:

```swift
struct SingleActionWorkflow: Workflow {
    typealias Output = Never

    @ObservableState
    struct State {
        var counter = 0
    }

    enum Action: WorkflowAction {
        typealias WorkflowType = SingleActionWorkflow
        case increment

        func apply(toState state: inout State) -> Never? {
            state.counter += 1
            return nil
        }
    }

    func makeInitialState() -> State {
        .init()
    }

    func render(
        state: State,
        context: RenderContext<Self>
    ) -> ActionModel<State, Action> {
        context.makeActionModel(state: state)
    }
}

```

For complex workflows that have multiple actions or compose observable models from child
workflows, you can create a custom model that conforms to `ObservableModel`:

```swift
struct ComplexWorkflow: Workflow {
    typealias Output = Never

    @ObservableState
    struct State {
        var counter = 0
    }

    enum UpAction: WorkflowAction {
        typealias WorkflowType = ComplexWorkflow
        case increment

        func apply(toState state: inout State) -> Never? {
            state.counter += 1
            return nil
        }
    }

    enum DownAction: WorkflowAction {
        typealias WorkflowType = ComplexWorkflow
        case decrement

        func apply(toState state: inout State) -> Never? {
            state.counter -= 1
            return nil
        }
    }

    func makeInitialState() -> State {
        .init()
    }

    func render(
        state: State,
        context: RenderContext<Self>
    ) -> CustomModel {
        CustomModel(
            accessor: context.makeStateAccessor(state: state),
            child: TrivialWorkflow().rendered(in: context),
            up: context.makeSink(of: UpAction.self),
            down: context.makeSink(of: DownAction.self)
        )
    }
}

struct CustomModel: ObservableModel {
    var accessor: StateAccessor<ComplexWorkflow.State>

    var child: TrivialWorkflow.Rendering

    var up: Sink<ComplexWorkflow.UpAction>
    var down: Sink<ComplexWorkflow.DownAction>
}
```

## Views

In your View, you’ll access state and sinks via a property of type `Store<Model>`. This type wraps the model that your workflow renders, and provides conveniences for access the state, sinks, and child stores.

If targeting iOS 16 or below, you’ll need to wrap your view’s body in `WithPerceptionTracking`. This is a component of the `Perception` backport that allows observation to work on iOS before iOS 17.

```swift
struct PersonState {
  var name: String
  var age: Int
}

enum PersonAction {
  case giveHighFive
}

typealias PersonModel = ActionModel<PersonState, PersonAction>

struct PersonView: View {
  let store: Store<PersonModel>
  
  var body: some View {
    WithPerceptionTracking {
      VStack {
        Text("Name: \(store.name)")
        Text("Age: \(store.age)")

        Button("✋") {
          store.send(.giveHighFive)
        }
      }
    }
  }
}
```

If you forget to wrap your view's body in `WithPerceptionTracking`, a runtime warning will remind you.

## Screens

In `WorkflowSwiftUI`, we recommend that workflows render models rather than screens. This strategy will help you to build smaller workflows and views that are more composable and reusable.

When you are ready to put a view in a screen, create a screen that implements `ObservableScreen`.

```swift
public protocol ObservableScreen: Screen {
    /// The type of the root view rendered by this screen.
    associatedtype Content: View
    /// The type of the model that this screen observes.
    associatedtype Model: ObservableModel

    /// The model that this screen observes.
    var model: Model { get }

    /// Constructs the root view for this screen. This is only called once to initialize the view.
    /// After the initial construction, the view will be updated by injecting new values into the
    /// store.
    @ViewBuilder
    static func makeView(store: Store<Model>) -> Content
}
```

Your screen will be relatively simple, as it has the relatively simple job of acting as the glue between your rendering model and your view type.

```swift
struct PersonScreen: ObservableScreen {
  let model: PersonModel

  static func makeView(store: Store<PersonModel>) -> PersonView {
    PersonView(store: store)
  }
}
```

To use this screen, render your workflow and then use the `mapRendering()` function to wrap your workflow’s model rendering in a screen.

## Composition

You can render child workflows, and pass their models through to child views.

When accessing a nested `ObservableModel` in your `Store`, it will automatically be mapped to a child store of type `Store<ChildModel>`

```swift
struct CoupleState {
  var person1ID: UUID
  var person2ID: UUID
}

struct CoupleWorkflow: Workflow {
  typealias State = CoupleState
  // <snip>
  func render(
    state: State,
    context: RenderContext<Self>
  ) -> CoupleModel {
    CoupleModel(
      accessor: context.makeStateAccessor(state: state),
      person1: PersonWorkflow(id: state.person1ID).rendered(in: context),
      person2: PersonWorkflow(id: state.person2ID).rendered(in: context)
    )
  }
}

struct CoupleModel: ObservableModel {
    var accessor: StateAccessor<CoupleState>

    var person1: PersonModel
    var person2: PersonModel
}

struct CoupleView: View {
  typealias Model = CoupleModel

  let store: Store<Model>
  
  var body: some View {
    HStack {
      PersonView(store: store.person1)
      PersonView(store: store.person2)
    }
  }
}
```

Child store mapping works for plain `ObservableModel` properties, as well as optionals, collections, and identified collections.

## Actions

If your model is a single-action `ActionModel` created by `context.makeActionModel()` , you can send actions by calling `send` on your `Store`.

For complex models with multiple sinks, you can access each sink on the model through the `Store` and send through them directly.

```swift
struct CustomModel: ObservableModel {
  var accessor: StateAccessor<State>

  var up: Sink<UpAction>
  var down: Sink<DownAction>
}

struct CustomView: View {
  typealias Model = CustomModel

  let store: Store<Model>
  
  var body: some View {
    WithPerceptionTracking {
      VStack {
        Button("Increment") {
          store.up.send(.increment)
        }
        Button("Decrement") {
          store.down.send(.decrement)
        }
      }
    }
  }
}
```

## Bindings

For state properties that are writable, an automatic `Binding` can be derived by annotating the store with `@Bindable`. These bindings will use the workflow's state mutation sink. If you’re targeting iOS 16 or lower, you should use `@Perception.Bindable`.

All properties can be turned into bindings by appending the `sending()` function to specify the “write” action. For properties that are already writable, this will refine the binding to send a custom action instead of the built-in state mutation sink.

```swift
@ObservableState
struct State {
   var isX: Bool
   private(set) var isY: Bool
}

@CasePathable
enum Action: WorkflowAction {
  case setY(Bool)

  func apply(toState state: inout State) -> Never? {
    switch self {
    case .setY(let value):
      state.isY = value
    }
    return nil
  }
}

typealias Model = ActionModel<State, Action>

struct ContentView: View {
  @Perception.Bindable var store: Store<Model>

  var body: some View {
    WithPerceptionTracking {
      // synthesized binding
      Toggle("X?", isOn: $store.isX)
      // binding with a custom setter action
      Toggle("Y?", isOn: $store.isY.sending(action: \.setY))
    }
  }
}
```

## Parent dependencies

Because `WorkflowSwiftUI` relies on observation to function, most properties on your model cannot be safely accessed directly through the `Store` — only the state, child models, and action sinks are accessible. So, when a workflow has dependencies provided by a parent (inputs, a.k.a. "props" in Kotlin), they must be added to your workflow’s own state in order to be visible by your view. They must also be updated in the `workflowDidChange` function of your workflow in order to receive updates from your parent.

When updating dependencies, remember that any value being set is considered a mutation by the observation framework. To avoid invalidating your view on every render, check if dependencies have actually changed before copying them.

Dependencies that conform to `@ObservableState` themselves can safely be assigned on every update.

```swift
@ObservableState
struct ChildState {
  var name: String
  var info: MiscInfo
}

@ObservableState
struct MiscInfo {
  var foo: String
  var bar: Int
}

struct ChildWorkflow: Workflow {
  typealias State = ChildState

  let name: String
  let info: MiscInfo

  func workflowDidChange(from previousWorkflow: ChildWorkflow, state: inout ChildState) {
    // For non-observable types, only update if the value has changed, 
    // so that we don't trigger a body re-evaluation on every render
    if name != previousWorkflow.name {
      state.name = name
    }

    // For observable types, we can just assign the new value.
    state.info = info
  }
}
```

## Previews

`WorkflowSwiftUI` has conveniences for creating static previews based on a view or screen, or stateful preview of a workflow and screen.

```swift
// static view preview
struct FooView_Preview: PreviewProvider {
  static var previews: some View {
    FooView(store: .preview(state: FooState()))
  }
}

// static screen preview
struct FooScreen_Preview: PreviewProvider {
  static var previews: some View {
    FooScreen.observableScreenPreview(state: FooState())
  }
}

// stateful workflow preview
struct FooWorkflow_Preview: PreviewProvider {
  static var previews: some View {
    FooWorkflow()
      .mapRendering(FooScreen.init)
      .workflowPreview()
  }
}
```
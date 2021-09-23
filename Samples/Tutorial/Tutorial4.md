# Step 4

_Refactoring and rebalancing a tree of Workflows_

## Setup

To follow this tutorial:
- Open your terminal and run `bundle exec pod install` in the `Samples/Tutorial` directory.
- Open `Tutorial.xcworkspace` and build the `Tutorial` Scheme.

Start from the implementation of `Tutorial3` if you're skipping ahead. You can do this by updating the `AppDelegate` to import `Tutorial3` instead of `TutorialBase`.

## Adding new todo items

A gap in the usability of the todo app is that it does not let the user create new todo items. We will add an "add" button on the right side of the navigation bar for this.

## Refactoring a workflow by splitting it into a parent and child

The `TodoListWorkflow` has started to grow and has multiple concerns it's handling — specifically all of the `ListScreen` behavior, as well as the actions that can come from the `TodoEditWorkflow`.

When a single workflow seems to be doing too many things, a common pattern is to extract some of its responsibilty into a parent.

### TodoWorkflow

Create a new workflow called `Todo` that will be responsible for both the `TodoListWorkflow` and  the `TodoEditWorkflow`.

```swift
import ReactiveSwift
import Workflow
import WorkflowReactiveSwift
import WorkflowUI


// MARK: Input and Output

struct TodoWorkflow: Workflow {
    enum Output {}
}

// ...rest of the template contents...
```

#### Moving logic from the TodoList to the TodoWorkflow

Move the `todo` state, input, and outputs from the `TodoListWorkflow` up to the `TodoWorkflow`. It will be owner the list of todo items, and the `TodoListWorkflow` will simply show whatever is passed into its input:

```swift
// TodoWorkflow.swift

// MARK: Input and Output

struct TodoWorkflow: Workflow {
    var name: String

    enum Output {
        case back
    }
}

// MARK: State and Initialization

extension TodoWorkflow {
    struct State {
        var todos: [TodoModel]
        var step: Step

        enum Step {
            // Showing the list of todo items.
            case list

            // Editing a single item. The state holds the index so it can be updated when a save action is received.
            case edit(index: Int)
        }
    }

    func makeInitialState() -> TodoWorkflow.State {
        return State(
            todos: [
                TodoModel(
                    title: "Take the cat for a walk",
                    note: "Cats really need their outside sunshine time. Don't forget to walk Charlie. Hamilton is less excited about the prospect."
                )
            ],
            step: .list
        )
    }

// ...rest of the implementation...
```

Define the output events from the `TodoListWorkflow` to describe the `new` item action and selecting a todo item, as well as removing the todo list from the `State`:

```swift
// TodoListWorkflow.swift
// MARK: Input and Output

struct TodoListWorkflow: Workflow {
    // The name is an input.
    var name: String
    // Use the list of todo items passed from our parent.
    var todos: [TodoModel]

    enum Output {
        case back
        case selectTodo(index: Int)
        case newTodo
    }
}


// MARK: State and Initialization

extension TodoListWorkflow {
    struct State {
    }

    func makeInitialState() -> TodoListWorkflow.State {
        return State()
    }

    func workflowDidChange(from previousWorkflow: TodoListWorkflow, state: inout State) {

    }
}
```

Change the `Action` behaviors to return an output instead of modifying any state:

```swift
// MARK: Actions

extension TodoListWorkflow {
    enum Action: WorkflowAction {
        typealias WorkflowType = TodoListWorkflow

        case onBack
        case selectTodo(index: Int)
        case new

        func apply(toState state: inout TodoListWorkflow.State) -> TodoListWorkflow.Output? {

            switch self {

            case .onBack:
                // When a `.onBack` action is received, emit a `.back` output
                return .back

            case .selectTodo(index: let index):
                // Tell our parent that a todo item was selected.
                return .selectTodo(index: index)

            case .new:
                // Tell our parent a new todo item should be created.
                return .newTodo
            }

        }
    }
}
```

Update the `render` method to only return the `TodoListScreen` as a `BackStackScreen.Item`, including the "new todo" button:

```swift
// MARK: Rendering

extension TodoListWorkflow {
    typealias Rendering = BackStackScreen<AnyScreen>.Item

    func render(state: TodoListWorkflow.State, context: RenderContext<TodoListWorkflow>) -> Rendering {
        // Define a sink to be able to send actions.
        let sink = context.makeSink(of: Action.self)

        let titles = todos.map(\.title)

        let todoListScreen = TodoListScreen(
            todoTitles: titles,
            onTodoSelected: { index in
                // Send the `selectTodo` action when a todo is selected in the UI.
                sink.send(.selectTodo(index: index))
            }
        )

        let todoListItem = BackStackScreen.Item(
            key: "list",
            screen: todoListScreen.asAnyScreen(),
            barContent: BackStackScreen.BarContent(
                title: "Welcome, \(name)",
                leftItem: .button(.back(handler: {
                    // When the left button is tapped, send the .onBack action.
                    sink.send(.onBack)
                })),
                rightItem: .button(BackStackScreen.BarContent.Button(
                    content: .text("New Todo"),
                    handler: {
                        sink.send(.new)
                    }
                ))
            )
        )

        return todoListItem
    }
}
```

Render the `TodoListWorkflow` and handle its output in the `TodoWorkflow`:

```swift
// MARK: Actions

extension TodoWorkflow {

    enum Action: WorkflowAction {
        typealias WorkflowType = TodoWorkflow

        case back
        case editTodo(index: Int)
        case newTodo

        func apply(toState state: inout TodoWorkflow.State) -> TodoWorkflow.Output? {
            switch self {
            case .back:
                return .back

            case .editTodo(index: let index):
                state.step = .edit(index: index)

            case .newTodo:
                // Append a new todo model to the end of the list.
                state.todos.append(TodoModel(
                    title: "New Todo",
                    note: ""
                ))
            }

            return nil
        }
    }
}


// MARK: Rendering

extension TodoWorkflow {
    typealias Rendering = [BackStackScreen<AnyScreen>.Item]

    func render(state: TodoWorkflow.State, context: RenderContext<TodoWorkflow>) -> Rendering {
        let todoListItem = TodoListWorkflow(name: name, todos: state.todos)
            .mapOutput { output -> Action in
                switch output {
                case .back:
                    return .back

                case .selectTodo(index: let index):
                    return .editTodo(index: index)

                case .newTodo:
                    return .newTodo
                }
            }
            .rendered(in: context)

        return [todoListItem]
    }
}
```

Update the `RootWorkflow` to defer to the `TodoWorkflow` for rendering the `todo` state. This will get us back into a state where we can build again (albeit without editing support):

```swift
// MARK: Rendering

extension RootWorkflow {
    typealias Rendering = BackStackScreen<AnyScreen>

    func render(state: RootWorkflow.State, context: RenderContext<RootWorkflow>) -> Rendering {

        // ... rest of the implementation ...

        switch state {
        case .welcome:
            // We always add the welcome screen to the backstack, so this is a no op.
            break

        case .todo(name: let name):
            // When the state is `.todo`, defer to the TodoListWorkflow.

            // was: let todoBackStackItems = TodoListWorkflow(name: name)
            let todoBackStackItems = TodoWorkflow(name: name)
                .mapOutput { output -> Action in
                    switch output {
                    case .back:
                        // When receiving a `.back` output, treat it as a `.logOut` action.
                        return .logOut
                    }
                }
                .rendered(in: context)

            // Add the todoBackStackItems to our backStackItems
            backStackItems.append(contentsOf: todoBackStackItems)
        }

        // Finally, return the BackStackScreen with a list of BackStackScreen.Items
        return BackStackScreen(items: backStackItems)
    }
}
```

#### Moving Edit Output handling to the TodoWorkflow

The `TodoWorkflow` now can handle the outputs from the `TodoListWorkflow`. Next, let's add handling for the `TodoEditWorkflow` output events.

Since the types of output and actions are pretty different from their origin, make a *second* action type on the `TodoWorkflow`:

```swift
// MARK: Actions

extension TodoWorkflow {

    // Was `enum Action: WorkflowAction {`
    enum ListAction: WorkflowAction {

    // ... rest of List action definition and implementation ...
    }


    enum EditAction: WorkflowAction {
        typealias WorkflowType = TodoWorkflow

        case discardChanges
        case saveChanges(todo: TodoModel, index: Int)

        func apply(toState state: inout TodoWorkflow.State) -> TodoWorkflow.Output? {
            guard case .edit = state.step else {
                fatalError("Received edit action when state was not `.edit`.")
            }

            switch self {
                case .discardChanges:
                    // When a discard action is received, return to the list.
                    state.step = .list

                case .saveChanges(todo: let todo, index: let index):
                    // When changes are saved, update the state of that `todo` item and return to the list.
                    state.todos[index] = todo
                    state.step = .list
            }

            return nil
        }
    }
}
```

Update the `render` method to show the `TodoEditWorkflow` screen when on the edit step:

```swift
// MARK: Rendering

extension TodoWorkflow {
    typealias Rendering = [BackStackScreen<AnyScreen>.Item]

    func render(state: TodoWorkflow.State, context: RenderContext<TodoWorkflow>) -> Rendering {
        let todoListItem = TodoListWorkflow(name: name, todos: state.todos)
            .mapOutput { output -> ListAction in
                switch output {
                case .back:
                    return .back

                case .selectTodo(index: let index):
                    return .editTodo(index: index)

                case .newTodo:
                    return .newTodo
                }
            }
            .rendered(in: context)

        switch state.step {
        case .list:
            // On the "list" step, return just the list screen.
            return [todoListItem]

        case .edit(index: let index):
            // On the "edit" step, return both the list and edit screens.
            let todoEditItem = TodoEditWorkflow(initialTodo: state.todos[index])
                .mapOutput { output -> EditAction in
                    switch output {
                    case .discard:
                        // Send the discardChanges actions when the discard output is received.
                        return .discardChanges

                    case .save(let todo):
                        // Send the saveChanges action when the save output is received.
                        return .saveChanges(todo: todo, index: index)
                    }
                }
                .rendered(in: context)

            return [todoListItem, todoEditItem]
        }
    }
}
```

That's it! There is now a workflow for both of our current steps of the Todo flow. We also used the ability to define multiple actions for a single workflow to keep the logic contained to the expected state we would receive the actions from.

## Conclusion

Is the code better after this refactor? It's debatable - having the logic in the `TodoListWorkflow` was probably ok for the scope of what the app is doing. However, if more screens are added to this flow it would be much easier to reason about, as there would be a single touchpoint controlling where we are within the subflow of viewing and editing todo items.

Additionally, now the `TodoList` and `TodoEdit` workflows are completely decoupled - there is no longer a requirement that the `TodoEdit` workflow is displayed after the list. For instance, we could change the list to have "viewing" or "editing" modes, where tapping on an item might only allow it to be viewed, but another mode would allow editing.

It comes down to the individual judgement of the developer to decide how a tree of workflows should be shaped - this was intended to provide two examples of how this _could_ be structured, but not specify how it _should_.

## Up Next

We now have a pretty fully formed app. However, if we want to keep adding features, we'll want to validate that existing features don't break while we're make improvements. In the next tutorial, we'll cover a couple of techniques for testing workflows.

[Tutorial 5](Tutorial5.md)
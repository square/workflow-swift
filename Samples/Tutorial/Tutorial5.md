# Step 5

_Unit and Integration Testing Workflows_

## Setup

To follow this tutorial:
- Open your terminal and run `bundle exec pod install` in the `Samples/Tutorial` directory.
- Open `Tutorial.xcworkspace` and build the `Tutorial` Scheme.
- The unit tests will run from the default scheme when pressing `cmd+shift+u`.

Start from the implementation of `Tutorial4` if you're skipping ahead. You can do this by updating the `AppDelegate` to import `Tutorial4` instead of `TutorialBase`.

# Testing

`Workflow`s being easily testable was a design requirement. It is essential to building scalable, reliable software.

The `WorkflowTesting` library is provided to allow easy unit and integration testing.

## Unit Tests (Actions)

A `WorkflowAction`'s `apply` function is effectively a reducer. Given a current state and action, it returns a new state (and optionally an output). Because an `apply` function should almost always be a "pure" function, it is a great candidate for unit testing.

The `WorkflowActionTester` is provided to facilitate writing unit tests against actions.

## WorkflowActionTester

The `WorkflowActionTester` is an extension on `WorkflowAction` which provides an easy to use harness for testing a series of actions and the resulting state updates. From the example in the source:
```swift
/// TestedWorkflow.Action
///     .tester(withState: .firstState)
///     .send(action: .exampleEvent)
///     .assert(output: .finished)
///     .assert(state: .differentState)
```

You provide an initial state, and drive the state forward by sending one action at a time. The `Output` can be validated after each action is sent; the `State` can be, as well.

### WelcomeWorkflow Tests

Start by creating a new Unit test file called `WelcomeWorkflowTests`. Import `WorkflowTesting` as well as a `@testable import` for the `Tutorial` pod you're testing:

We'll use the `@testable import` to be able to test our workflows which are not exposed publicly.

```swift
import XCTest
@testable import TutorialBase
import WorkflowTesting


class WelcomeWorkflowTests: XCTestCase {
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
}
```

For the `WelcomeWorkflow`, we will start by testing that the `name` property is updated on the state every time a `.nameChanged` action is received:

```swift
import XCTest
@testable import TutorialBase
import WorkflowTesting


class WelcomeWorkflowTests: XCTestCase {
    func testNameUpdates() throws {
        WelcomeWorkflow.Action
            .tester(withState: WelcomeWorkflow.State(name: ""))
            .send(action: .nameChanged(name: "myName"))
            // No output is expected when the name changes.
            .assertNoOutput()
            .verifyState { state in
                // The `name` has been updated from the action.
                XCTAssertEqual("myName", state.name)
            }
    }
}
```

The `Output` of an action can also be tested. Next, we'll add a test for the `.didLogIn` action.

```swift
    func testLogIn() throws {
        WelcomeWorkflow.Action
            .tester(withState: WelcomeWorkflow.State(name: ""))
            .send(action: .didLogIn)
            .verifyOutput { output in
                // A `.didLogIn` output should be emitted with the name when the `.didLogIn` action was received.
                switch output {
                case .didLogIn(name: let name):
                    XCTAssertEqual("", name)
                }
            }
    }
```

We have now validated that an output is emitted when the `.didLogIn` action is received. However, while writing this test, it probably doesn't make sense to allow someone to log in without providing a name. Let's update the test to ensure that login is only allowed when there is a name:

```swift
    func testLogIn() throws {
        WelcomeWorkflow.Action
            .tester(withState: WelcomeWorkflow.State(name: ""))
            .send(action: .didLogIn)
            // Since the name is empty, `.didLogIn` will not emit an output.
            .assertNoOutput()
            .verifyState { state in
                // The name is empty, as was specified in the initial state.
                XCTAssertEqual("", state.name)
            }
            .send(action: .nameChanged(name: "Ada"))
            // Update the name, no output expected.
            .assertNoOutput()
            .verifyState { state in
                // Validate the name was updated.
                XCTAssertEqual("Ada", state.name)
            }
            .send(action: .didLogIn)
            .verifyOutput { output in
                // Now a `.didLogIn` output should be emitted when the `.didLogIn` action was received.
                switch output {
                case .didLogIn(name: let name):
                    XCTAssertEqual("Ada", name)
                }
            }
    }
```

The test will now fail, as a `.didLogIn` action will still cause `.didLogIn` output when the name is blank. Update the `WelcomeWorkflow` logic to reflect the new behavior we want:

```swift
// MARK: Actions

extension WelcomeWorkflow {
    enum Action: WorkflowAction {
        typealias WorkflowType = WelcomeWorkflow

        case nameChanged(name: String)
        case didLogIn

        func apply(toState state: inout WelcomeWorkflow.State) -> WelcomeWorkflow.Output? {
            switch self {
            case .nameChanged(name: let name):
                // Update our state with the updated name.
                state.name = name
                // Return `nil` for the output, we want to handle this action only at the level of this workflow.
                return nil

            case .didLogIn:
                if state.name.isEmpty {
                    // Don't log in if the name isn't filled in.
                    return nil
                } else {
                    // Return an output of `didLogIn` with the name.
                    return .didLogIn(name: state.name)
                }
            }
        }
    }
}
```

Run the test again and ensure that it passes. Additionally, run the app to see that it also reflects the updated behavior.

### TodoListWorkflow

Add tests for the `TodoListWorkflow`. They'll be pretty simple, as this workflow is stateless and all actions are simply forwarded to the parent as outputs:

```swift
import XCTest
@testable import TutorialBase
import WorkflowTesting

class TodoListWorkflowTests: XCTestCase {
    func testActions() throws {
        TodoListWorkflow.Action
            .tester(withState: TodoListWorkflow.State())
            .send(action: .onBack)
            .verifyOutput { output in
                // The `.onBack` action should emit an output of `.back`.
                switch output {
                case .back:
                    break  // Expected
                default:
                    XCTFail("Expected an output of `.back`")
                }
            }
            .send(action: .selectTodo(index: 7))
            .verifyOutput { output in
                // The `.selectTodo` action should emit a `.selectTodo` output.
                switch output {
                case .selectTodo(index: let index):
                    XCTAssertEqual(7, index)
                default:
                    XCTFail("Expected an output of `.selectTodo`")
                }
            }
            .send(action: .new)
            .verifyOutput { output in
                // The `.new` action should emit a `.newTodo` output.
                switch output {
                case .newTodo:
                    break  // Expected
                default:
                    XCTFail("Expected an output of `.newTodo`")
                }
            }
    }
}
```

### TodoEditWorkflow

The `TodoEditWorkflow` has a bit more complexity since it holds a local copy of the todo to be edited. Start by adding tests for the actions:

```swift
import XCTest
@testable import TutorialBase
import WorkflowTesting

class TodoEditWorkflowTests: XCTestCase {
    func testAction() throws {
        TodoEditWorkflow.Action
            // Start with a todo of "Title" "Note"
            .tester(withState: TodoEditWorkflow.State(todo: TodoModel(title: "Title", note: "Note")))
            .verifyState { state in
                XCTAssertEqual("Title", state.todo.title)
                XCTAssertEqual("Note", state.todo.note)
            }
            // Update the title to "Updated Title"
            .send(action: .titleChanged("Updated Title"))
            .assertNoOutput()
            // Validate that only the title changed.
            .verifyState { state in
                XCTAssertEqual("Updated Title", state.todo.title)
                XCTAssertEqual("Note", state.todo.note)
            }
            // Update the note.
            .send(action: .noteChanged("Updated Note"))
            .assertNoOutput()
            // Validate that the note was updated.
            .verifyState { state in
                XCTAssertEqual("Updated Title", state.todo.title)
                XCTAssertEqual("Updated Note", state.todo.note)
            }
            // Send a `.discardChanges` action, which will emit a `.discard` output.
            .send(action: .discardChanges)
            .verifyOutput { output in
                switch output {
                case .discard:
                    break  // Expected
                default:
                    XCTFail("Expected an output of `.discard`")
                }
            }
            // Send a `.saveChanges` action, which will emit a `.save` output with the updated todo model.
            .send(action: .saveChanges)
            .verifyOutput { output in
                switch output {
                case .save(let todo):
                    XCTAssertEqual("Updated Title", todo.title)
                    XCTAssertEqual("Updated Note", todo.note)
                default:
                    XCTFail("Expected an output of `.save`")
                }
            }
    }
}
```

The `TodoEditWorkflow` also uses the `workflowDidChange` to update the internal state if its parent provides it with a different `todo`. Validate that this works as expected:

```swift
    func testChangedPropertyUpdatesLocalState() throws {
        let initialWorkflow = TodoEditWorkflow(initialTodo: TodoModel(title: "Title", note: "Note"))
        var state = initialWorkflow.makeInitialState()

        // The initial state is a copy of the provided todo:
        XCTAssertEqual("Title", state.todo.title)
        XCTAssertEqual("Note", state.todo.note)

        // Mutate the internal state, simulating the change from actions:
        state.todo.title = "Updated Title"

        // Update the workflow properties with the same value. The state should not be updated:
        initialWorkflow.workflowDidChange(from: initialWorkflow, state: &state)
        XCTAssertEqual("Updated Title", state.todo.title)
        XCTAssertEqual("Note", state.todo.note)

        // The parent provided different properties. The internal state should be updated with the newly-provided properties.
        let updatedWorkflow = TodoEditWorkflow(initialTodo: TodoModel(title: "New Title", note: "New Note"))
        updatedWorkflow.workflowDidChange(from: initialWorkflow, state: &state)
        XCTAssertEqual("New Title", state.todo.title)
        XCTAssertEqual("New Note", state.todo.note)
    }
```

## Testing Rendering

Testing actions is very useful for validating all of the state transitions of a workflow, but it is also beneficial to verify the logic in `render`. Since the `render` method uses a private implementation of a `RenderContext`, there is a `RenderTester` to facilitate testing.

## RenderTester

The `renderTester` extension on `Workflow` provides an easy way to test the rendering of a workflow. The simple usage of validating a rendering is shown in the doc comments:
```swift
workflow
    .renderTester()
    .render { rendering in
        XCTAssertEqual("expected text on rendering", rendering.text)
    }
```

It also provides a means to test that closures passed to screens cause the correct actions and state changes:

```swift
workflow
    .renderTester()
    .render { rendering in
        XCTAssertEqual("expected text on rendering", rendering.text)
        rendering.updateText("updated")
    }
    .assert(
        state: TestWorkflow.State(text: "updated")
    )
```

The full API allows for expected workers and (child) workflows, as well as verification of resulting state and output:
```swift
workflow
    .renderTester(initialState: State())
    .expectWorkflow(
        type: ChildWorkflow.self,
        producingRendering: ChildScreen(),
        producingOutput: .closed
    )
    .expect(
        worker: TestWorker(),
        producingOutput: .finished
    )
    .render { rendering in
        XCTAssertEqual("expected text on rendering", rendering.text)
    }
    .assert(state: TestWorkflow.State(text: "updated"))
    .assert(output: .completed)
```

### WelcomeWorkflow

Add tests for the rendering of the `WelcomeWorkflow`:

```swift
// WelcomeWorkflowTests.swift

    func testRenderingInitial() throws {
        WelcomeWorkflow()
            // Use the initial state provided by the welcome workflow.
            .renderTester()
            .render { screen in
                XCTAssertEqual("", screen.name)

                // Simulate tapping the log in button. No output will be emitted, as the name is empty.
                screen.onLoginTapped()
            }
            .assertNoOutput()
    }

    func testRenderingNameChange() throws {
        WelcomeWorkflow()
            // Use the initial state provided by the welcome workflow.
            .renderTester()
            // Next, simulate the name updating, expecting the state to be changed to reflect the updated name.
            .render { screen in
                screen.onNameChanged("Ada")
            }
            .verifyState { state in
                XCTAssertEqual("Ada", state.name)
            }
    }

    func testRenderingLogIn() throws {
        WelcomeWorkflow()
            // Start with a name already entered.
            .renderTester(initialState: WelcomeWorkflow.State(name: "Ada"))
            // Simulate a log in button tap.
            .render { screen in
                screen.onLoginTapped()
            }
            // Finally, validate that `.didLogIn` was sent.
            .verifyOutput { output in
                switch output {
                case .didLogIn(name: "Ada"):
                    break  // Pass
                default:
                    XCTFail("Unexpected output \(output)")
                }
            }
    }
```

Since the `State` and `Output` on the `WelcomeWorkflow` aren't equatable, we had to write our own equivalence method for them. To simplify this test, instead let's have both conform to `Equatable` to make the test a bit easier to read:

```swift
// MARK: Input and Output

struct WelcomeWorkflow: Workflow {
    enum Output: Equatable {
        case didLogIn(name: String)
    }
}


// MARK: State and Initialization

extension WelcomeWorkflow {
    struct State: Equatable {
        var name: String
    }

// ... rest of the implementation ...
```

Update the last two tests to take advantage of the `Equatable` conformance:

```swift
    func testRenderingNameChange() throws {
        WelcomeWorkflow()
            // Use the initial state provided by the welcome workflow.
            .renderTester()
            // Next, simulate the name updating, expecting the state to be changed to reflect the updated name.
            .render { screen in
                screen.onNameChanged("Ada")
            }
            .assert(state: WelcomeWorkflow.State(name: "Ada"))
    }

    func testRenderingLogIn() throws {
        WelcomeWorkflow()
            // Start with a name already entered.
            .renderTester(initialState: WelcomeWorkflow.State(name: "Ada"))
            // Simulate a log in button tap.
            .render { screen in
                screen.onLoginTapped()
            }
            // Finally, validate that `.didLogIn` was sent.
            .assert(output: .didLogIn(name: "Ada"))
    }
```

Add tests against the `render` methods of the `TodoEdit` and `TodoList` workflows as desired.

## Composition Testing

We've demonstrated how to test leaf workflows for their actions and renderings. However, the power of workflow is the ability to compose a tree of workflows. The `RenderTester` provides tools to test workflows with children.

`ExpectedWorkflow` allows us to describe a child workflow that is expected to be rendered in the next render pass. It is given the type of child, an optional key, and the mock rendering to return. It can also provide an optional output:

```swift
public struct ExpectedWorkflow {
    public init<WorkflowType: Workflow>(type: WorkflowType.Type, key: String = "", rendering: WorkflowType.Rendering, output: WorkflowType.Output? = nil)
}
```

### RootWorkflow Tests

The `RootWorkflow` is responsible for the entire state of our app. We can skip testing the actions with the `ActionTester`, as that will be handled by testing the rendering.

Start by adding `Equatable` conformance to the `State` to simplify the tests:

```swift
extension RootWorkflow {
    // The state is an enum, and can either be on the welcome screen or the todo list.
    // When on the todo list, it also includes the name provided on the welcome screen
    enum State: Equatable {
        // The welcome screen via the welcome workflow will be shown
        case welcome
        // The todo list screen via the todo list workflow will be shown. The name will be provided to the todo list.
        case todo(name: String)
    }
```

And first we can test the `.welcome` state on its own:

```swift
import XCTest
@testable import TutorialBase
import WorkflowTesting
// Import `BackStackContainer` as testable so that the items in the `BackStackScreen` can be inspected.
@testable import BackStackContainer
// Import `WorkflowUI` as testable so that the wrappedScreen in `AnyScreen` can be accessed.
@testable import WorkflowUI

class RootWorkflowTests: XCTestCase {
    func testWelcomeRendering() throws {
        RootWorkflow()
            // Start in the `.welcome` state
            .renderTester(initialState: .welcome)
            // The `WelcomeWorkflow` is expected to be started in this render.
            .expectWorkflow(
                type: WelcomeWorkflow.self,
                producingRendering: WelcomeScreen(
                    name: "Ada",
                    onNameChanged: { _ in },
                    onLoginTapped: {}
                )
            )
            // Now, validate that there is a single item in the BackStackScreen, which is our welcome screen.
            .render { rendering in
                XCTAssertEqual(1, rendering.items.count)
                guard let welcomeScreen = rendering.items[0].screen.wrappedScreen as? WelcomeScreen else {
                    XCTFail("Expected first screen to be a `WelcomeScreen`")
                    return
                }

                XCTAssertEqual("Ada", welcomeScreen.name)
            }
            // Assert that no action was produced during this render, meaning our state remains unchanged
            .assertNoOutput()
    }
}
```

We needed to use a few `@testable` imports to inspect the underlying screen (since both the `BackStackScreen` and `AnyScreen` use type-erasure), but we've been able to validate that the `RootWorkflow` renders as expected.

Now, we can also test the transition from the `.welcome` state to the `.todo` state:

```swift
    func testLogIn() throws {
        RootWorkflow()
            // Start in the `.welcome` state
            .renderTester(initialState: .welcome)
            // The `WelcomeWorkflow` is expected to be started in this render.
            .expectWorkflow(
                type: WelcomeWorkflow.self,
                producingRendering: WelcomeScreen(
                    name: "Ada",
                    onNameChanged: { _ in },
                    onLoginTapped: {}
                ),
                // Simulate the `WelcomeWorkflow` sending an out0put of `.didLogIn` as if the "log in" button was tapped.
                producingOutput: .didLogIn(name: "Ada")
            )
            // Now, validate that there is a single item in the BackStackScreen, which is our welcome screen (prior to the output).
            .render { rendering in
                XCTAssertEqual(1, rendering.items.count)
                guard let welcomeScreen = rendering.items[0].screen.wrappedScreen as? WelcomeScreen else {
                    XCTFail("Expected first screen to be a `WelcomeScreen`")
                    return
                }
                XCTAssertEqual("Ada", welcomeScreen.name)
            }
            // Assert that the state transitioned to `.todo`
            .assert(state: .todo(name: "Ada"))
    }
```

By simulating the output from the `WelcomeWorkflow`, we were able to drive the `RootWorkflow` forward. This was much more of an integration test than a "pure" unit test, but we have now validated the same behavior we see by testing the app by hand.

### TodoWorkflow Render Tests

Now add tests for the `TodoWorkflow`, so that we have relatively full coverage. These are two examples, of selecting and saving a todo to validate the transitions between screens, as well as updating the state in the parent (Add `Equatable` conformance to `TodoWorkflow.State` to simplify the tests):

```swift
import XCTest
@testable import TutorialBase
import BackStackContainer
import WorkflowTesting
import WorkflowUI

class TodoWorkflowTests: XCTestCase {
    func testSelectingTodo() throws {
        let todos: [TodoModel] = [TodoModel(title: "Title", note: "Note")]

        TodoWorkflow(name: "Ada")
            // Start from the list step to validate selecting a todo.
            .renderTester(initialState: TodoWorkflow.State(
                todos: todos,
                step: .list
            ))
            // We only expect the TodoListWorkflow to be rendered.
            .expectWorkflow(
                type: TodoListWorkflow.self,
                producingRendering: BackStackScreen<AnyScreen>.Item(
                    screen: TodoListScreen(todoTitles: ["Title"], onTodoSelected: { _ in }).asAnyScreen()
                ),
                // Simulate selecting the first todo.
                producingOutput: .selectTodo(index: 0)
            )
            .render { items in
                // Just validate that there is one item in the back stack.
                // Additional validation could be done on the screens returned, if desired.
                XCTAssertEqual(1, items.count)
            }
            // Assert that the state was updated after the render pass with the output from the TodoListWorkflow.
            .assert(state: TodoWorkflow.State(
                todos: [TodoModel(title: "Title", note: "Note")],
                step: .edit(index: 0)
            ))
    }

    func testSavingTodo() throws {
        let todos: [TodoModel] = [TodoModel(title: "Title", note: "Note")]

        TodoWorkflow(name: "Ada")
            // Start from the edit step so we can simulate saving.
            .renderTester(initialState: TodoWorkflow.State(
                todos: todos,
                step: .edit(index: 0)
            ))
            // We always expect the TodoListWorkflow to be rendered.
            .expectWorkflow(
                type: TodoListWorkflow.self,
                producingRendering: BackStackScreen<AnyScreen>.Item(
                    screen: TodoListScreen(
                        todoTitles: ["Title"],
                        onTodoSelected: { _ in }
                    ).asAnyScreen()
                )
            )
            // Expect the TodoEditWorkflow to be rendered as well (as we're on the edit step).
            .expectWorkflow(
                type: TodoEditWorkflow.self,
                producingRendering: BackStackScreen<AnyScreen>.Item(
                    screen: TodoEditScreen(
                        title: "Title",
                        note: "Note",
                        onTitleChanged: { _ in },
                        onNoteChanged: { _ in }
                    ).asAnyScreen()
                ),
                // Simulate it emitting an output of `.save` to update the state.
                producingOutput: .save(TodoModel(
                    title: "Updated Title",
                    note: "Updated Note"
                ))
            )
            .render { items in
                // Just validate that there are two items in the back stack.
                // Additional validation could be done on the screens returned, if desired.
                XCTAssertEqual(2, items.count)
            }
            // Validate that the state was updated after the render pass with the output from the TodoEditWorkflow.
            .assert(state: TodoWorkflow.State(
                todos: [TodoModel(title: "Updated Title", note: "Updated Note")],
                step: .list
            ))
    }
}
```

## Integration Testing

The `RenderTester` allows easy "mocking" of child workflows and workers. However, this means that we are not exercising the full infrastructure (even though we could get a fairly high confidence from the tests). Sometimes, it may be worth putting together integration tests that test a full tree of Workflows.

Add another test to `RootWorkflowTests`. We will run the tree of workflows in a `WorkflowHost`, which is what the infrastructure uses for a `ContainerViewController`. This will be a "black box" test, as we can only test the behaviors from the rendering and will not be able to inspect the underlying states. This may be a useful test for validation when refactoring a tree of workflows to ensure they behave the same way.

```swift
// RootWorkflowTests.swift
    func testAppFlow() throws {
        // Note: You'll need to `import Workflow` in order to use `WorkflowHost`
        let workflowHost = WorkflowHost(workflow: RootWorkflow())

        // First rendering is just the welcome screen. Update the name.
        do {
            let backStack = workflowHost.rendering.value
            XCTAssertEqual(1, backStack.items.count)

            guard let welcomeScreen = backStack.items[0].screen.wrappedScreen as? WelcomeScreen else {
                XCTFail("Expected initial screen of `WelcomeScreen`")
                return
            }

            welcomeScreen.onNameChanged("Ada")
        }

        // Log in and go to the todo list.
        do {
            let backStack = workflowHost.rendering.value
            XCTAssertEqual(1, backStack.items.count)

            guard let welcomeScreen = backStack.items[0].screen.wrappedScreen as? WelcomeScreen else {
                XCTFail("Expected initial screen of `WelcomeScreen`")
                return
            }

            welcomeScreen.onLoginTapped()
        }

        // Expect the todo list to be rendered. Edit the first todo.
        do {
            let backStack = workflowHost.rendering.value
            XCTAssertEqual(2, backStack.items.count)

            guard let _ = backStack.items[0].screen.wrappedScreen as? WelcomeScreen else {
                XCTFail("Expected first screen of `WelcomeScreen`")
                return
            }

            guard let todoScreen = backStack.items[1].screen.wrappedScreen as? TodoListScreen else {
                XCTFail("Expected second screen of `TodoListScreen`")
                return
            }

            XCTAssertEqual(1, todoScreen.todoTitles.count)

            // Select the first todo.
            todoScreen.onTodoSelected(0)
        }

        // Selected a todo to edit. Expect the todo edit screen.
        do {
            let backStack = workflowHost.rendering.value
            XCTAssertEqual(3, backStack.items.count)

            guard let _ = backStack.items[0].screen.wrappedScreen as? WelcomeScreen else {
                XCTFail("Expected first screen of `WelcomeScreen`")
                return
            }

            guard let _ = backStack.items[1].screen.wrappedScreen as? TodoListScreen else {
                XCTFail("Expected second screen of `TodoListScreen`")
                return
            }

            guard let editScreen = backStack.items[2].screen.wrappedScreen as? TodoEditScreen else {
                XCTFail("Expected third screen of `TodoEditScreen`")
                return
            }

            // Update the title.
            editScreen.onTitleChanged("New Title")
        }

        // Save the selected todo.
        do {
            let backStack = workflowHost.rendering.value
            XCTAssertEqual(3, backStack.items.count)

            guard let _ = backStack.items[0].screen.wrappedScreen as? WelcomeScreen else {
                XCTFail("Expected first screen of `WelcomeScreen`")
                return
            }

            guard let _ = backStack.items[1].screen.wrappedScreen as? TodoListScreen else {
                XCTFail("Expected second screen of `TodoListScreen`")
                return
            }

            guard let _ = backStack.items[2].screen.wrappedScreen as? TodoEditScreen else {
                XCTFail("Expected second screen of `TodoEditScreen`")
                return
            }

            // Save the changes by tapping the right bar button.
            // This also validates that the navigation bar was described as expected.
            switch backStack.items[2].barVisibility {

            case .hidden:
                XCTFail("Expected a visible navigation bar")

            case .visible(let barContent):
                switch barContent.rightItem {

                case .none:
                    XCTFail("Expected a right bar button")

                case .button(let button):

                    switch button.content {

                    case .text(let text):
                        XCTAssertEqual("Save", text)

                    case .icon:
                        XCTFail("Expected the right bar button to have a title of `Save`")
                    }
                    // Tap the right bar button to save.
                    button.handler()
                }
            }
        }

        // Expect the todo list. Validate the title was updated.
        do {
            let backStack = workflowHost.rendering.value
            XCTAssertEqual(2, backStack.items.count)

            guard let _ = backStack.items[0].screen.wrappedScreen as? WelcomeScreen else {
                XCTFail("Expected first screen of `WelcomeScreen`")
                return
            }

            guard let todoScreen = backStack.items[1].screen.wrappedScreen as? TodoListScreen else {
                XCTFail("Expected second screen of `TodoListScreen`")
                return
            }

            XCTAssertEqual(1, todoScreen.todoTitles.count)
            XCTAssertEqual("New Title", todoScreen.todoTitles[0])
        }
    }
```

This test was *very* verbose, and rather long. Generally, it's not recommended to do full integration tests like this (the action tests and render tests can give pretty solid coverage of a workflow's behavior). However, this is an example of how it might be done in case it's needed.

# Conclusion

This was intended as a guide of how testing can be facilitated with the `WorkflowTesting` library provided for workflows. As always, it is up to the judgement of the developer of what and how their software should be tested.

# Step 1

_Let's get something on the screen..._

## Setup

To follow this tutorial:
- Open your terminal and run `tuist generate` in the `Samples/Tutorial` directory.
- After the project opens, build the `Tutorial-Workspace` Scheme.

The `TutorialBase` module in `Samples/Tutorial/Project/Frameworks/TutorialBase` will be our starting place to build from.

The welcome screen should look like:

![Welcome](images/welcome.png)

You can enter a name, but the login button won't do anything.

## First Workflow

Let's start by making a workflow and screen to back the welcome view.

Start by creating a new workflow and screen by creating a new file with the [Xcode templates](../../Tooling/Templates/install-xcode-templates.sh), adding it to the `TutorialBase` target:

![New Workflow](images/new-workflow.png)
![Workflow Name](images/workflow-name.png)
![File Location](images/workflow-file-location.png)

Follow the same steps using the `Screen (View Controller)` template. We can delete the `WelcomeSampleViewController.swift` file in the base tutorial, as we'll be replacing it.

### Screens and View Controllers

Let's start with what a `Screen` is, and how it relates to the view controller.

The `Screen` protocol is a marker protocol, intended to describe the view model that will be used to drive a view controller.

For our welcome screen, we'll define what it needs for a backing view model:
```swift
struct WelcomeScreen: Screen {
    /// The current name that has been entered.
    var name: String
    /// Callback when the name changes in the UI.
    var onNameChanged: (String) -> Void
    /// Callback when the login button is tapped.
    var onLoginTapped: () -> Void

    func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
        return WelcomeViewController.description(for: self, environment: environment)
    }
}
```

Now add the (convenient) `WelcomeView` to our view controller (if you would like to create and lay out the view yourself, feel free to do so!). Add a `welcomeView` property to the view controller, and add and lay it out in `viewDidLoad` and `viewDidLayoutSubviews` respectively.
```swift
// Import the `TutorialViews` module for the `WelcomeView`
import TutorialViews

final class WelcomeViewController: ScreenViewController<WelcomeScreen> {
    private var welcomeView: WelcomeView!

    required init(screen: WelcomeScreen, environment: ViewEnvironment) {
        super.init(screen: screen, environment: environment)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        welcomeView = WelcomeView(frame: view.bounds)
        view.addSubview(welcomeView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        welcomeView.frame = view.bounds.inset(by: view.safeAreaInsets)
    }
```

The screen is passed into the view controller when it is initialized. `screenDidChange` is called as part of the view controller's initialization (see `ViewControllerDescription.buildViewController`) and anytime the backing screen is updated. Keep in mind, however, that the `welcomeView` will be `nil` until the view is loaded, so we'll need to guard against that to avoid unwrapping the optional. Additionally, when `viewDidLoad` _is_ called and we create the `WelcomeView` we will need to update it with the contents of the `WelcomeScreen`. To accomplish both of these, we'll create a separate helper method that both code paths can utilize:
```swift
    override func viewDidLoad() {
        super.viewDidLoad()

        welcomeView = WelcomeView(frame: view.bounds)
        view.addSubview(welcomeView)

        updateView(with: screen)
    }

    override func screenDidChange(from previousScreen: WelcomeScreen, previousEnvironment: ViewEnvironment) {
        super.screenDidChange(from: previousScreen, previousEnvironment: previousEnvironment)

        guard isViewLoaded else { return }

        updateView(with: screen)
    }

    private func updateView(with screen: WelcomeScreen) {
        welcomeView.name = screen.name
        welcomeView.onNameChanged = screen.onNameChanged
        welcomeView.onLoginTapped = screen.onLoginTapped
    }
```

Any time the screen is updated, the `WelcomeViewController` will now update the `name`, `onNameChanged`, and `onLoginTapped` fields on the `WelcomeView`. We can't quite run yet, as we still need to fill in the basics of our workflow.

### Workflows and Rendering Type

The core responsibility of a workflow is to provide a "rendering" every time the related state updates. Let's go into the `WelcomeWorkflow` now, and have it return a `WelcomeScreen` in the `render` method.

```swift
// MARK: Rendering

extension WelcomeWorkflow {
    typealias Rendering = WelcomeScreen

    func render(state: WelcomeWorkflow.State, context: RenderContext<WelcomeWorkflow>) -> Rendering {
        return WelcomeScreen(
            name: "",
            onNameChanged: { newName in
            },
            onLoginTapped: {
            })
    }
}
```

### Setting up the WorkflowHostingController

Now we have our `WelcomeWorkflow` rendering a `WelcomeScreen`, and have a view controller that knows how to display with a `WelcomeScreen`. It's time to bind this all together and actually show it on the screen!

We'll update the `TutorialContainerViewController` to hold a child *WorkflowHostingController* that will host our workflow:

```swift
import UIKit
import Workflow
import WorkflowUI


public final class TutorialHostingViewController: UIViewController {
    let containerViewController: UIViewController

    public init() {
        // Create a `WorkflowHostingController` with the `WelcomeWorkflow` as the root workflow.
        containerViewController = WorkflowHostingController(
            workflow: WelcomeWorkflow()
        )

        super.init(nibName: nil, bundle: nil)
    }
```

Now, we've created our `WorkflowHostingController` with the `WelcomeWorkflow` as the root.

We can finally run the app again! It will look exactly the same as before, but now it is powered by our workflow.

## Driving the UI from Workflow State

Right now, the workflow isn't handling any of the events from the UI. Let's update it to be responsible for the login name as well as the action when the login button is pressed.

### State

All workflows have a `State` type that represents the internal state of the workflow. This should be all of the data for which *this* workflow is _responsible_. It usually corresponds to the state for the UI.

Let's model the first part of state that we want to track: the login `name`. Update the `State` type to include a name property. We will also need to update `makeInitialState` to give an initial value:

```swift
// MARK: State and Initialization

extension WelcomeWorkflow {

    struct State {
        var name: String
    }

    func makeInitialState() -> WelcomeWorkflow.State {
        return State(name: "")
    }

    // ...
```

Now that we have the state modeled, we'll send it to the UI every time a render pass happens. The text field will overwrite its value with whatever was provided.

```swift
// MARK: Rendering

extension WelcomeWorkflow {

    typealias Rendering = WelcomeScreen

    func render(state: WelcomeWorkflow.State, context: RenderContext<WelcomeWorkflow>) -> Rendering {
        return WelcomeScreen(
            name: state.name,
            onNameChanged: { newName in
            },
            onLoginTapped: {
            })
    }
}
```

If you run the app again, you'll see that it still behaves the same, letting your type into the name field. This is because we have only rendered the screen once.

You may have noticed that your workflow only has access to its `State` in a few functions, and even then in many cases it is read-only. This is intentional. The Workflow infrastructure manages the state for the various workflows that are running and triggers a re-render when appropriate. In order to update the workflow's internal state, we need to add an "Action":

### Actions

Actions define how a workflow handles events received from the outside world, such as UI events (e.g. button presses), network requests, data stores, etc. Generally an `Action` type is an enum which makes it easy to define all of the actions that this workflow will handle.

Add a case to the existing `Action` called `nameChanged` to update our internal state:

```swift
// MARK: Actions

extension WelcomeWorkflow {

    enum Action: WorkflowAction {

        typealias WorkflowType = WelcomeWorkflow

        case nameChanged(name: String)

        func apply(toState state: inout WelcomeWorkflow.State) -> WelcomeWorkflow.Output? {

            switch self {

            case .nameChanged(name: let name):
                // Update our state with the updated name.
                state.name = name
                // Return `nil` for the output, we want to handle this action only at the level of this workflow.
                return nil
            }
        }
    }

}
```

We need to send this action back to the workflow any time the name changes. Update the `render` method to send it through a sink back to the workflow whenever the `onNameChanged` closure is called:

```swift
// MARK: Rendering

extension WelcomeWorkflow {

    typealias Rendering = WelcomeScreen

    func render(state: WelcomeWorkflow.State, context: RenderContext<WelcomeWorkflow>) -> Rendering {
        // Create a "sink" of type `Action`. A sink is what we use to send actions to the workflow.
        let sink = context.makeSink(of: Action.self)

        return WelcomeScreen(
            name: state.name,
            onNameChanged: { name in
                sink.send(.nameChanged(name: name))
            },
            onLoginTapped: {
            })
    }
}
```

### The update loop

If we run the app again, it will still behave the same but we are now capturing the name changes in our workflow's state, as well as having the UI show the name based upon the workflow's internal state.

To see this, change the `apply` method to append an extra letter on the name received, eg:
```swift
        func apply(toState state: inout WelcomeWorkflow.State) -> WelcomeWorkflow.Output? {

            switch self {
            case .nameChanged(name: let name):
                // Update our state with the updated name.
                state.name = name + "a"
                // Return `nil` for the output, we want to handle this action only at the level of this workflow.
                return nil
            }
        }
```

Running the app again will have the name field suffixed with a letter 'a' on every keypress. We probably want to undo this change, but it demonstrates that the UI is being updated from the internal state.

Here is what is happening on each keypress:
1) The UI calls `onNameChanged` whenever the contents of the text field change.
2) The closure calls `sink.send(.nameChanged(name: name)`, which sends an action to be handled by the workflow.
3) The `apply` method on the action is called. The `state` parameter is an `inout` parameter, so when it is updated in `apply`, it updates the actual state.
    - This is effectively the same as this method being written `func apply(fromState: State) -> (State, Output?)` where it transforms the previous state into a new state.
4) As an action was just handled, the workflow must now be re-rendered so the `Screen` (and from it, the UI) can be updated.
    - `render` is called on the workflow. A new screen is returned with the updated `name` from the internal state.
5) The view controller is provided the new screen with the call to `func screenDidChange(from previousScreen: WelcomeScreen, previousEnvironment: ViewEnvironment)`.
    - This view controller updates the text field with the received name value, and also updates the callbacks for when the name changes or login is pressed.
6) The workflow waits for the next Action to be received, and then the goes through the same update loop.

# Summary

In this tutorial, we covered creating a Screen, ScreenViewController, Workflow, and binding them together in a `WorkflowHostingController`. We also covered the Workflow being responsible for the state of the UI instead of the view controller being responsible.

Next, we will create a second screen and workflow, and the use composition to navigate between them.

[Tutorial 2](Tutorial2.md)

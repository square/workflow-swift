/*
 * Copyright 2020 Square Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import BackStackContainer
import ReactiveSwift
import Workflow
import WorkflowReactiveSwift
import WorkflowUI

// MARK: Input and Output

struct RootWorkflow: Workflow {
    enum Output {}
}

// MARK: State and Initialization

extension RootWorkflow {
    // The state is an enum, and can either be on the welcome screen or the todo list.
    // When on the todo list, it also includes the name provided on the welcome screen.
    enum State {
        // The welcome screen via the welcome workflow will be shown.
        case welcome
        // The todo list screen via the todo list workflow will be shown. The name will be provided to the todo list.
        case todo(name: String)
    }

    func makeInitialState() -> RootWorkflow.State {
        .welcome
    }

    func workflowDidChange(from previousWorkflow: RootWorkflow, state: inout State) {}
}

// MARK: Actions

extension RootWorkflow {
    enum Action: WorkflowAction {
        typealias WorkflowType = RootWorkflow

        case logIn(name: String)
        case logOut

        func apply(toState state: inout RootWorkflow.State, context: ActionContext<WorkflowType>) -> RootWorkflow.Output? {
            switch self {
            case .logIn(name: let name):
                // When the `login` action is received, change the state to `todo`.
                state = .todo(name: name)
            case .logOut:
                // Return to the welcome state on logout.
                state = .welcome
            }

            return nil
        }
    }
}

// MARK: Workers

extension RootWorkflow {
    struct RootWorker: Worker {
        enum Output {}

        func run() -> SignalProducer<Output, Never> {
            fatalError()
        }

        func isEquivalent(to otherWorker: RootWorker) -> Bool {
            true
        }
    }
}

// MARK: Rendering

extension RootWorkflow {
    typealias Rendering = BackStackScreen<AnyScreen>

    func render(state: RootWorkflow.State, context: RenderContext<RootWorkflow>) -> Rendering {
        // Create a sink to handle the back action from the TodoListWorkflow to log out.
        let sink = context.makeSink(of: Action.self)

        // Our list of back stack items. Will always include the "WelcomeScreen".
        var backStackItems: [BackStackScreen<AnyScreen>.Item] = []

        let welcomeScreen = WelcomeWorkflow()
            .mapOutput { output -> Action in
                switch output {
                // When `WelcomeWorkflow` emits `didLogIn`, turn it into our `logIn` action.
                case .didLogIn(name: let name):
                    return .logIn(name: name)
                }
            }
            .rendered(in: context)

        let welcomeBackStackItem = BackStackScreen.Item(
            key: "welcome",
            screen: AnyScreen(welcomeScreen),
            // Hide the navigation bar.
            barVisibility: .hidden
        )

        // Always add the welcome back stack item.
        backStackItems.append(welcomeBackStackItem)

        switch state {
        case .welcome:
            // We always add the welcome screen to the backstack, so this is a no op.
            break

        case .todo(name: let name):
            // When the state is `.todo`, defer to the TodoListWorkflow.
            let todoListScreen = TodoListWorkflow()
                .rendered(in: context)

            let todoListBackStackItem = BackStackScreen.Item(
                key: "todoList",
                screen: AnyScreen(todoListScreen),
                // Specify the title, back button, and right button.
                barContent: BackStackScreen.BarContent(
                    title: "Welcome \(name)",
                    // When `back` is pressed, emit the .logOut action to return to the welcome screen.
                    leftItem: .button(.back(handler: {
                        sink.send(.logOut)
                    })),
                    rightItem: .none
                )
            )

            // Add the TodoListScreen to our BackStackItems.
            backStackItems.append(todoListBackStackItem)
        }

        // Finally, return the BackStackScreen with a list of BackStackScreen.Items
        return BackStackScreen(items: backStackItems)
    }
}

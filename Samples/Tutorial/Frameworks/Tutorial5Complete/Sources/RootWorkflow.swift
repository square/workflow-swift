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
    // When on the todo list, it also includes the name provided on the welcome screen
    enum State: Equatable {
        // The welcome screen via the welcome workflow will be shown
        case welcome
        // The todo list screen via the todo list workflow will be shown. The name will be provided to the todo list.
        case todo(name: String)
    }

    func makeInitialState() -> RootWorkflow.State {
        return .welcome
    }

    func workflowDidChange(from previousWorkflow: RootWorkflow, state: inout State) {}
}

// MARK: Actions

extension RootWorkflow {
    enum Action: WorkflowAction {
        typealias WorkflowType = RootWorkflow

        case logIn(name: String)
        case logOut

        func apply(toState state: inout RootWorkflow.State) -> RootWorkflow.Output? {
            switch self {
            case .logIn(name: let name):
                state = .todo(name: name)
            case .logOut:
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
            return true
        }
    }
}

// MARK: Rendering

extension RootWorkflow {
    typealias Rendering = BackStackScreen<AnyScreen>

    func render(state: RootWorkflow.State, context: RenderContext<RootWorkflow>) -> Rendering {
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
            screen: welcomeScreen.asAnyScreen(),
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

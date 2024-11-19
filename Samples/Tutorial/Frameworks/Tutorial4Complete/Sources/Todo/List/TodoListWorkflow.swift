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
    struct State {}

    func makeInitialState() -> TodoListWorkflow.State {
        State()
    }

    func workflowDidChange(from previousWorkflow: TodoListWorkflow, state: inout State) {}
}

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
                .back

            case .selectTodo(index: let index):
                // Tell our parent that a todo item was selected.
                .selectTodo(index: index)

            case .new:
                // Tell our parent a new todo item should be created.
                .newTodo
            }
        }
    }
}

// MARK: Workers

extension TodoListWorkflow {
    struct TodoListWorker: Worker {
        enum Output {}

        func run() -> SignalProducer<Output, Never> {
            fatalError()
        }

        func isEquivalent(to otherWorker: TodoListWorker) -> Bool {
            true
        }
    }
}

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
            barContent: .init(
                title: "Welcome, \(name)",
                leftItem: .button(.back(handler: {
                    // When the left button is tapped, send the .onBack action.
                    sink.send(.onBack)
                })),
                rightItem: .button(.init(
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

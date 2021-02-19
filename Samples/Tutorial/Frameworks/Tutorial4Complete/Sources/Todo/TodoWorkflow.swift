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
                ),
            ],
            step: .list
        )
    }

    func workflowDidChange(from previousWorkflow: TodoWorkflow, state: inout State) {}
}

// MARK: Actions

extension TodoWorkflow {
    enum ListAction: WorkflowAction {
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

// MARK: Workers

extension TodoWorkflow {
    struct TodoWorker: Worker {
        enum Output {}

        func run() -> SignalProducer<Output, Never> {
            fatalError()
        }

        func isEquivalent(to otherWorker: TodoWorker) -> Bool {
            return true
        }
    }
}

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

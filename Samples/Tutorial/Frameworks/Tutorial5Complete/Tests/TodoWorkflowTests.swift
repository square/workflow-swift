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
import Workflow
import WorkflowTesting
import WorkflowUI
import XCTest
@testable import Tutorial5

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

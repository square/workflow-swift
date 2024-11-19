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

import Workflow
import WorkflowTesting
import XCTest

// Import `BackStackContainer` as testable so that the items in the `BackStackScreen` can be inspected.
@testable import BackStackContainer
@testable import Tutorial5Complete

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
                XCTFail("Expected second screen of `TodoEditScreen`")
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
}

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

import WorkflowTesting
import XCTest
@testable import Tutorial5Complete

class WelcomeWorkflowTests: XCTestCase {
    func testNameUpdates() throws {
        WelcomeWorkflow.Action
            .tester(workflow: WelcomeWorkflow())
            .send(action: .nameChanged(name: "myName"))
            // No output is expected when the name changes.
            .assertNoOutput()
            .verifyState { state in
                // The `name` has been updated from the action.
                XCTAssertEqual("myName", state.name)
            }
    }

    func testLogIn() throws {
        WelcomeWorkflow.Action
            .tester(workflow: WelcomeWorkflow())
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
}

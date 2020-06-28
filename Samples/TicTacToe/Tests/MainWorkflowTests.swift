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
import ModalContainer
import Workflow
import WorkflowTesting
import XCTest

@testable import Development_SampleTicTacToe

class MainWorkflowTests: XCTestCase {
    // MARK: Action Tests

    func test_action_authenticated() {
        MainWorkflow
            .Action
            .tester(withState: .authenticating)
            .send(action: .authenticated(sessionToken: "token"))
            .assertState { state in
                if case MainWorkflow.State.runningGame(let token) = state {
                    XCTAssertEqual(token, "token")
                } else {
                    XCTFail("Invalid state after authenticated")
                }
            }
    }

    func test_action_logout() {
        MainWorkflow
            .Action
            .tester(withState: .runningGame(sessionToken: "token"))
            .send(action: .logout)
            .assertState { state in
                XCTAssertEqual(state, .authenticating)
            }
    }

    // MARK: Render Tests

    func test_render_authenticating() {
        MainWorkflow()
            .renderTester()
            .expectWorkflow(
                type: AuthenticationWorkflow.self,
                producingRendering: AuthenticationWorkflow.Rendering(
                    baseScreen: ModalContainerScreen(
                        baseScreen: BackStackScreen(items: []), modals: []
                    ),
                    alert: nil
                )
            )
            .render { screen in
                XCTAssertNil(screen.alert)
            }
            .verifyNoAction()
    }

    func disabled_test_render_runningGame() {
        MainWorkflow()
            .renderTester()
            .render { screen in
                XCTAssertNil(screen.alert)
            }
            .verify(state: .runningGame(sessionToken: "token"))
    }
}

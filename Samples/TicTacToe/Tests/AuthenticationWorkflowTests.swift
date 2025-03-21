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
import WorkflowReactiveSwiftTesting
import WorkflowTesting
import XCTest

@testable import TicTacToe

class AuthenticationWorkflowTests: XCTestCase {
    // MARK: Action Tests

    func test_action_back() {
        AuthenticationWorkflow
            .Action
            .tester(
                workflow: workflow,
                state: .twoFactor(intermediateSession: "test", authenticationError: nil)
            )
            .send(action: .back)
            .assert(state: .emailPassword)
    }

    func test_action_login() {
        AuthenticationWorkflow
            .Action
            .tester(workflow: workflow)
            .send(action: .login(email: "reza@example.com", password: "password"))
            .verifyState { state in
                if case .authorizingEmailPassword(let email, let password) = state {
                    XCTAssertEqual(email, "reza@example.com")
                    XCTAssertEqual(password, "password")
                } else {
                    XCTFail("Unexpected emailPassword in state \(state)")
                }
            }
    }

    func test_action_verifySecondFactor() {
        AuthenticationWorkflow
            .Action
            .tester(workflow: workflow)
            .send(
                action: .verifySecondFactor(
                    intermediateSession: "intermediateSession",
                    twoFactorCode: "twoFactorCode"
                )
            )
            .verifyState { state in
                if case .authorizingTwoFactor(let twoFactorCode, let intermediateSession) = state {
                    XCTAssertEqual(intermediateSession, "intermediateSession")
                    XCTAssertEqual(twoFactorCode, "twoFactorCode")
                } else {
                    XCTFail("Unexpected verifySecondFactor in state \(state)")
                }
            }
    }

    func test_action_authenticationSucceeded() {
        AuthenticationWorkflow
            .Action
            .tester(workflow: workflow)
            .send(
                action: .authenticationSucceeded(
                    response: AuthenticationService.AuthenticationResponse(
                        token: "token",
                        secondFactorRequired: true
                    )
                )
            )
            .verifyState { state in
                if case .twoFactor(let intermediateSession, let authenticationError) = state {
                    XCTAssertEqual(intermediateSession, "token")
                    XCTAssertNil(authenticationError)
                } else {
                    XCTFail("Unexpected authenticationSucceeded in state \(state)")
                }
            }

        AuthenticationWorkflow
            .Action
            .tester(workflow: workflow)
            .send(
                action: .authenticationSucceeded(
                    response: AuthenticationService.AuthenticationResponse(
                        token: "token",
                        secondFactorRequired: false
                    )
                )
            )
            .verifyOutput { output in
                switch output {
                case .authorized(session: let session):
                    XCTAssertEqual(session, "token")
                }
            }
            .assert(state: .emailPassword)
    }

    func test_action_dismissAuthenticationAlert() {
        AuthenticationWorkflow
            .Action
            .tester(
                workflow: workflow,
                state: .authorizingEmailPassword(email: "test@example.com", password: "password")
            )
            .send(
                action: .authenticationError(AuthenticationService.AuthenticationError.invalidUserPassword)
            )
            .verifyState { state in
                if case .authenticationErrorAlert(let error) = state {
                    XCTAssertNotNil(error)
                    XCTAssertEqual(error, AuthenticationService.AuthenticationError.invalidUserPassword)
                } else {
                    XCTFail("Unexpected authenticationError in state \(state)")
                }
            }
            .send(action: .dismissAuthenticationAlert)
            .assert(state: .emailPassword)
    }

    func test_action_authenticationError() {
        AuthenticationWorkflow
            .Action
            .tester(
                workflow: workflow,
                state: .authorizingEmailPassword(email: "test@example.com", password: "password")
            )
            .send(
                action: .authenticationError(AuthenticationService.AuthenticationError.invalidUserPassword)
            )
            .verifyState { state in
                if case .authenticationErrorAlert(let error) = state {
                    XCTAssertNotNil(error)
                    XCTAssertEqual(error, AuthenticationService.AuthenticationError.invalidUserPassword)
                } else {
                    XCTFail("Unexpected authenticationError in state \(state)")
                }
            }

        AuthenticationWorkflow
            .Action
            .tester(
                workflow: workflow,
                state: .authorizingTwoFactor(twoFactorCode: "123456", intermediateSession: "session")
            )
            .send(
                action: .authenticationError(AuthenticationService.AuthenticationError.invalidTwoFactor)
            )
            .verifyState { state in
                if case .twoFactor(let intermediateSession, let error) = state {
                    XCTAssertNotNil(intermediateSession)
                    XCTAssertNotNil(error)
                    XCTAssertEqual(error, AuthenticationService.AuthenticationError.invalidTwoFactor)
                } else {
                    XCTFail("Unexpected authenticationError in state \(state)")
                }
            }
    }

    // MARK: Render Tests

    func test_render_initial() {
        workflow
            .renderTester(initialState: .emailPassword)
            .expectWorkflow(
                type: LoginWorkflow.self,
                producingRendering: LoginScreen(
                    title: "",
                    email: "",
                    onEmailChanged: { _ in },
                    password: "",
                    onPasswordChanged: { _ in },
                    onLoginTapped: {}
                )
            )
            .render { screen in
                XCTAssertNil(screen.alert)
            }
            .assertNoAction()
    }

    func test_render_AuthorizingEmailPasswordWorker() {
        let authenticationService = AuthenticationService()

        workflow
            .renderTester(
                initialState: .authorizingEmailPassword(
                    email: "reza@example.com",
                    password: "password"
                )
            )
            .expectWorkflow(
                type: LoginWorkflow.self,
                producingRendering: LoginScreen(
                    title: "",
                    email: "",
                    onEmailChanged: { _ in },
                    password: "",
                    onPasswordChanged: { _ in },
                    onLoginTapped: {}
                )
            )
            .expect(
                worker: AuthenticationWorkflow.AuthorizingEmailPasswordWorker(
                    authenticationService: authenticationService,
                    email: "reza@example.com",
                    password: "password"
                )
            )
            .render { screen in
                XCTAssertNil(screen.alert)
            }
            .assertNoAction()
    }

    func test_render_authorizingTwoFactorWorker() {
        let authenticationService = AuthenticationService()

        workflow
            .renderTester(
                initialState: .authorizingTwoFactor(
                    twoFactorCode: "twoFactorCode",
                    intermediateSession: "intermediateSession"
                )
            )
            .expectWorkflow(
                type: LoginWorkflow.self,
                producingRendering: LoginScreen(
                    title: "",
                    email: "",
                    onEmailChanged: { _ in },
                    password: "",
                    onPasswordChanged: { _ in },
                    onLoginTapped: {}
                )
            )
            .expect(
                worker: AuthenticationWorkflow.AuthorizingTwoFactorWorker(
                    authenticationService: authenticationService,
                    intermediateToken: "intermediateSession",
                    twoFactorCode: "twoFactorCode"
                )
            )
            .render { screen in
                XCTAssertNil(screen.alert)
            }
            .assertNoAction()
    }

    func test_render_authenticationErrorAlert() {
        let authenticationService = AuthenticationService()

        workflow
            .renderTester(
                initialState: .authenticationErrorAlert(error: AuthenticationService.AuthenticationError.invalidUserPassword)
            )
            .expectWorkflow(
                type: LoginWorkflow.self,
                producingRendering: LoginScreen(
                    title: "",
                    email: "",
                    onEmailChanged: { _ in },
                    password: "",
                    onPasswordChanged: { _ in },
                    onLoginTapped: {}
                )
            )
            .render { screen in
                XCTAssertNotNil(screen.alert)
            }
    }
}

private let workflow = AuthenticationWorkflow(
    authenticationService: AuthenticationService()
)

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

import ReactiveSwift
import Workflow
import WorkflowUI

// MARK: Input and Output

struct LoginWorkflow: Workflow {
    enum Output {
        case login(email: String, password: String)
    }
}

// MARK: State and Initialization

extension LoginWorkflow {
    struct State {
        var email: String
        var password: String
    }

    func makeInitialState() -> LoginWorkflow.State {
        State(email: "", password: "")
    }
}

// MARK: Actions

extension LoginWorkflow {
    enum Action: WorkflowAction {
        typealias WorkflowType = LoginWorkflow

        case emailUpdated(String)
        case passwordUpdated(String)
        case login

        func apply(toState state: inout LoginWorkflow.State) -> LoginWorkflow.Output? {
            switch self {
            case .emailUpdated(let email):
                state.email = email

            case .passwordUpdated(let password):
                state.password = password

            case .login:
                return .login(email: state.email, password: state.password)
            }

            return nil
        }
    }
}

// MARK: Rendering

extension LoginWorkflow {
    typealias Rendering = LoginScreen

    func render(state: LoginWorkflow.State, context: RenderContext<LoginWorkflow>) -> Rendering {
        let sink = context.makeSink(of: Action.self)

        return LoginScreen(
            title: "Welcome! Please log in to play TicTacToe!",
            email: state.email,
            onEmailChanged: { email in
                sink.send(.emailUpdated(email))
            },
            password: state.password,
            onPasswordChanged: { password in
                sink.send(.passwordUpdated(password))
            },
            onLoginTapped: {
                sink.send(.login)
            }
        )
    }
}

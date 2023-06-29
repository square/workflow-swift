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
import WorkflowSwiftUI
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
        return State(email: "", password: "")
    }
}

// MARK: Actions

extension LoginWorkflow {
    enum Action: WorkflowAction {
        typealias WorkflowType = LoginWorkflow

        case login

        func apply(toState state: inout LoginWorkflow.State) -> LoginWorkflow.Output? {
            switch self {
            case .login:
                return .login(email: state.email, password: state.password)
            }
        }
    }
}

// MARK: Rendering

extension LoginWorkflow {
    typealias Rendering = LoginScreen

    func render(state: LoginWorkflow.State, context: RenderContext<LoginWorkflow>) -> Rendering {
        func binding<T>(_ keyPath: WritableKeyPath<State, T>) -> Writable<T> {
            let sink = context.makeSink(of: SetterAction<Self, T>.self)
            return Writable(
                value: state[keyPath: keyPath],
                set: { value in sink.send(.set(keyPath, to: value)) }
            )
        }
        return LoginScreen(
            actionSink: context.makeSink(),
            title: "Welcome! Please log in to play TicTacToe!",
            email: binding(\.email),
            password: binding(\.password)
        )
    }
}

public struct SetterAction<WorkflowType: Workflow, Value>: WorkflowAction {
    public typealias KeyPath = WritableKeyPath<WorkflowType.State, Value>

    private let keyPath: KeyPath
    private let value: Value

    public static func set(_ keyPath: KeyPath, to value: Value) -> Self {
        Self(keyPath: keyPath, value: value)
    }

    public func apply(toState state: inout WorkflowType.State) -> WorkflowType.Output? {
        state[keyPath: keyPath] = value
        return nil
    }
}

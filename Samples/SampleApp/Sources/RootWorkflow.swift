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

struct RootWorkflow: Workflow {
    typealias Output = Never
}

// MARK: State and Initialization

extension RootWorkflow {
    enum State {
        case welcome
        case demo(name: String)
    }

    func makeInitialState() -> RootWorkflow.State {
        .welcome
    }
}

// MARK: Actions

extension RootWorkflow {
    enum Action: WorkflowAction {
        typealias WorkflowType = RootWorkflow

        case login(name: String)

        func apply(toState state: inout RootWorkflow.State) -> RootWorkflow.Output? {
            switch self {
            case .login(name: let name):
                state = .demo(name: name)
            }

            return nil
        }
    }
}

// MARK: Rendering

extension RootWorkflow {
    typealias Rendering = CrossFadeScreen

    func render(state: RootWorkflow.State, context: RenderContext<RootWorkflow>) -> Rendering {
        switch state {
        case .welcome:
            CrossFadeScreen(
                base: WelcomeWorkflow()
                    .mapOutput { output -> Action in
                        switch output {
                        case .login(name: let name):
                            return .login(name: name)
                        }
                    }
                    .rendered(in: context)
            )

        case .demo(name: let name):
            CrossFadeScreen(
                base: DemoWorkflow(name: name)
                    .rendered(in: context)
            )
        }
    }
}

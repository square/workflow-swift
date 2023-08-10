/*
 * Copyright 2023 Square Inc.
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

// MARK: Input and Output

struct MainWorkflow: Workflow {
    typealias Output = Never
}

// MARK: State and Initialization

extension MainWorkflow {
    enum State: Equatable {
        case initial
    }

    func makeInitialState() -> MainWorkflow.State {
        return .initial
    }
}

// MARK: Actions

extension MainWorkflow {
    enum Action: WorkflowAction {
        typealias WorkflowType = MainWorkflow

        func apply(toState state: inout MainWorkflow.State) -> MainWorkflow.Output? {
            switch self {}
        }
    }
}

// MARK: Rendering

extension MainWorkflow {
    typealias Rendering = MainScreen

    func render(state: MainWorkflow.State, context: RenderContext<MainWorkflow>) -> Rendering {
        switch state {
        case .initial:
            return MainScreen()
        }
    }
}

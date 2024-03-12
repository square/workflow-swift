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

import ComposableArchitecture // for ObservableState
import MarketWorkflowUI
import Workflow
import CasePaths

struct MainWorkflow: Workflow {
    let didClose: (() -> Void)?

    enum Output {
        case pushScreen
        case presentScreen
    }

    @ObservableState
    struct State {
        var title: String
        var isAllCaps: Bool {
            didSet {
                title = isAllCaps ? title.uppercased() : title.lowercased()
            }
        }

        init(title: String) {
            self.title = title
            self.isAllCaps = title.isAllCaps
        }
    }

    func makeInitialState() -> State {
        State(title: "New item")
    }

    @CasePathable
    enum Action: WorkflowAction, Equatable {
        typealias WorkflowType = MainWorkflow

        case pushScreen
        case presentScreen
        case titleChanged(String)
        case allCapsChanged(Bool)
        case appendStar

        func apply(toState state: inout WorkflowType.State) -> WorkflowType.Output? {
            switch self {
            case .pushScreen:
                return .pushScreen
            case .presentScreen:
                return .presentScreen
            case .allCapsChanged(let allCaps):
                state.isAllCaps = allCaps
                return nil
            case .titleChanged(let newTitle):
                state.title = newTitle
                return nil
            case .appendStar:
                state.title += "*"
                return nil
            }
        }
    }

    typealias Rendering = StoreModel<State, Action>

    func render(state: State, context: RenderContext<Self>) -> Rendering {
        print("MainWorkflow.render")

        return StoreModel(
            state: state,
            sendAction: context.makeSink(of: Action.self).send,
            sendValue: context.makeStateMutationSink().send
        )
    }
}

extension MainWorkflow.State {

    var allCapsToggleIsEnabled: Bool {
        !title.isEmpty
    }
}

private extension String {
    var isAllCaps: Bool {
        allSatisfy { character in
            character.isUppercase || !character.isCased
        }
    }
}

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

import MarketWorkflowUI
import Workflow

struct MainWorkflow: Workflow {
    let didClose: (() -> Void)?

    enum Output {
        case pushScreen
        case presentScreen
    }

    struct State {
        var title: String
        var isAllCaps: Bool
    }

    func makeInitialState() -> State {
        State(title: "New item", isAllCaps: false)
    }

    enum Action: WorkflowAction {
        typealias WorkflowType = MainWorkflow

        case pushScreen
        case presentScreen
        case changeTitle(newValue: String)
        case changeAllCaps(isAllCaps: Bool)

        func apply(toState state: inout WorkflowType.State) -> WorkflowType.Output? {
            switch self {
            case .pushScreen:
                return .pushScreen
            case .presentScreen:
                return .presentScreen
            case .changeTitle(let newValue):
                state.title = newValue
                state.isAllCaps = newValue.allSatisfy { character in
                    character.isUppercase || !character.isCased
                }
            case .changeAllCaps(let isAllCaps):
                state.isAllCaps = isAllCaps
                state.title = isAllCaps ? state.title.uppercased() : state.title.lowercased()
            }
            return nil
        }
    }

    typealias Rendering = MainScreen

    func render(state: State, context: RenderContext<Self>) -> Rendering {
        let sink = context.makeSink(of: Action.self)

        return MainScreen(
            title: state.title,
            didChangeTitle: { sink.send(.changeTitle(newValue: $0)) },
            allCapsToggleIsOn: state.isAllCaps,
            didChangeAllCapsToggle: { sink.send(.changeAllCaps(isAllCaps: $0)) },
            didTapPushScreen: { sink.send(.pushScreen) },
            didTapPresentScreen: { sink.send(.presentScreen) },
            didTapClose: didClose
        )
    }
}

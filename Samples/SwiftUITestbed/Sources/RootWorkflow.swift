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
import WorkflowUI

struct RootWorkflow: Workflow {
    typealias Output = Never

    struct State {
        var backStack: BackStack
        var modals: [Screen]

        struct BackStack {
            let root: Screen
            var other: [Screen]
        }

        enum Screen {
            case placeholder
            case main
        }
    }

    func makeInitialState() -> State {
        State(
            backStack: .init(root: .placeholder, other: [.main]),
            modals: []
        )
    }

    enum Action: WorkflowAction {
        typealias WorkflowType = RootWorkflow

        case main(MainWorkflow.Output)
        case popScreen
        case dismissScreen

        func apply(toState state: inout WorkflowType.State) -> WorkflowType.Output? {
            switch self {
            case .main(.pushScreen):
                state.backStack.other.append(.placeholder)
            case .main(.presentScreen):
                state.modals.append(.placeholder)
            case .popScreen:
                state.backStack.other.removeLast()
            case .dismissScreen:
                state.modals.removeLast()
            }
            return nil
        }
    }

    typealias Rendering = ModalContainer<BackStack, AnyScreen>
    typealias BackStack = MarketBackStack<AnyMarketBackStackContentScreen>

    func render(state: State, context: RenderContext<Self>) -> Rendering {
        let sink = context.makeSink(of: Action.self)

        func rendering(_ screen: State.Screen) -> AnyMarketBackStackContentScreen {
            switch screen {
            case .main:
                return MainWorkflow()
                    .mapOutput(Action.main)
                    .mapRendering(AnyMarketBackStackContentScreen.init)
                    .rendered(in: context)
            case .placeholder:
                return PlaceholderScreen()
                    .asAnyMarketBackStackContentScreen()
            }
        }

        func backStackContent(_ screen: State.Screen) -> BackStack.Content {
            rendering(screen)
                .asContent(onPop: { sink.send(.popScreen) })
        }

        let backStack = MarketBackStack(
            root: backStackContent(state.backStack.root),
            other: state.backStack.other.map(backStackContent)
        )

        return Rendering(
            base: backStack,
            modals: state.modals.enumerated().map { index, screen in
                Modal(
                    key: index,
                    style: .full(),
                    screen: rendering(screen).asMarketBackStack(with: .init {
                        $0.backButton = .close { sink.send(.dismissScreen) }
                    })
                )
            }
        )
    }
}

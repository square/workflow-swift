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
    let close: (() -> Void)?

    typealias Output = Never

    struct State {
        var backStack: BackStack
        var isPresentingModal: Bool

        struct BackStack {
            let root: Screen
            var other: [Screen] = []
        }

        enum Screen {
            case main(id: UUID = UUID())
        }
    }

    func makeInitialState() -> State {
        State(
            backStack: .init(root: .main()),
            isPresentingModal: false
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
                state.backStack.other.append(.main())
            case .main(.presentScreen):
                state.isPresentingModal = true
            case .popScreen:
                state.backStack.other.removeLast()
            case .dismissScreen:
                state.isPresentingModal = false
            }
            return nil
        }
    }

    typealias Rendering = ModalContainer<BackStack, AnyScreen>
    typealias BackStack = MarketBackStack<AnyMarketBackStackContentScreen>

    func render(state: State, context: RenderContext<Self>) -> Rendering {
        let sink = context.makeSink(of: Action.self)

        func rendering(_ screen: State.Screen, isRoot: Bool) -> AnyMarketBackStackContentScreen {
            switch screen {
            case .main(let id):
                return MainWorkflow(didClose: isRoot ? close : nil)
                    .mapOutput(Action.main)
                    .mapRendering(AnyMarketBackStackContentScreen.init)
                    .rendered(in: context, key: id.uuidString)
            }
        }

        func backStackContent(_ screen: State.Screen, isRoot: Bool) -> BackStack.Content {
            rendering(screen, isRoot: isRoot)
                .asContent(onPop: { sink.send(.popScreen) })
        }

        let backStack = MarketBackStack(
            root: backStackContent(state.backStack.root, isRoot: true),
            other: state.backStack.other.map { backStackContent($0, isRoot: false) }
        )

        return Rendering(
            base: backStack,
            modals: {
                guard state.isPresentingModal else { return [] }
                let screen = RootWorkflow(close: { sink.send(.dismissScreen) })
                    .rendered(in: context)
                    .asAnyScreen()
                let modal = Modal(
                    key: "",
                    style: .full(),
                    content: screen
                )
                return [modal]
            }()
        )
    }
}

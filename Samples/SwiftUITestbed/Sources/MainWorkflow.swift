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

// MARK: Input and Output

struct MainWorkflow: Workflow {
    typealias Output = Never
}

// MARK: State and Initialization

extension MainWorkflow {
    enum State: Equatable {
        case initial
        case screenPushed
        case screenPresented
    }

    func makeInitialState() -> MainWorkflow.State {
        return .initial
    }
}

// MARK: Actions

extension MainWorkflow {
    enum Action: WorkflowAction {
        typealias WorkflowType = MainWorkflow

        case pushScreen
        case popScreen
        case presentScreen
        case dismissScreen

        func apply(toState state: inout MainWorkflow.State) -> MainWorkflow.Output? {
            switch self {
            case .pushScreen:
                state = .screenPushed
            case .popScreen:
                state = .initial
            case .presentScreen:
                state = .screenPresented
            case .dismissScreen:
                state = .initial
            }
            return nil
        }
    }
}

// MARK: Rendering

extension MainWorkflow {
    typealias Rendering = ModalContainer<
        MarketBackStack<AnyMarketBackStackContentScreen>,
        MarketDialogScreen
    >

    func render(state: MainWorkflow.State, context: RenderContext<MainWorkflow>) -> Rendering {
        let sink = context.makeSink(of: Action.self)

        let rootScreen = MainScreen(
            didTapPushScreen: { sink.send(.pushScreen) },
            didTapPresentScreen: { sink.send(.presentScreen) }
        ).asAnyMarketBackStackContentScreen()

        var modalContainer = Rendering(
            base: MarketBackStack(root: rootScreen)
        )

        switch state {
        case .initial:
            break
        case .screenPushed:
            modalContainer.base.add(
                screen: PlaceholderScreen().asAnyMarketBackStackContentScreen(),
                onPop: { sink.send(.popScreen) }
            )
        case .screenPresented:
            modalContainer.modals.append(Modal(
                key: "modal",
                content: MarketDialogScreen(
                    title: "Lorem ipsum dolor",
                    message: "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
                    primaryAction: .init(
                        text: "Dismiss",
                        onTap: { sink.send(.dismissScreen) }
                    )
                )
            ))
        }

        return modalContainer
    }
}

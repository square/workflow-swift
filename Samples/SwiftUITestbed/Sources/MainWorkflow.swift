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
    let canClose: Bool

    enum Output {
        case pushScreen
        case presentScreen
        case close
    }

    struct State {
        var title: String
        var isAllCaps: Bool
        let trampoline = SinkTrampoline()

        init(title: String) {
            self.title = title
            self.isAllCaps = title.isAllCaps
        }
    }

    func makeInitialState() -> State {
        State(title: "New item")
    }

    typealias Rendering = MainScreen
    typealias Action = MainScreen.Action

    func render(state: State, context: RenderContext<Self>) -> Rendering {
        let sink = state.trampoline.makeSink(of: Action.self, with: context)

        return MainScreen(
            title: state.title,
            didChangeTitle: { sink.send(.changeTitle($0)) },
            canClose: canClose,
            allCapsToggleIsOn: state.isAllCaps,
            allCapsToggleIsEnabled: !state.title.isEmpty,
            didChangeAllCapsToggle: { sink.send(.changeAllCaps($0)) },
            didTapPushScreen: { sink.send(.pushScreen) },
            didTapPresentScreen: { sink.send(.presentScreen) },
            didTapClose: canClose ? { sink.send(.close) } : nil
        )
    }
}

extension MainScreen.Action: WorkflowAction {
    typealias WorkflowType = MainWorkflow

    func apply(toState state: inout WorkflowType.State) -> WorkflowType.Output? {
        switch self {
        case .pushScreen:
            return .pushScreen
        case .presentScreen:
            return .presentScreen
        case .changeTitle(let newValue):
            state.title = newValue
            state.isAllCaps = newValue.isAllCaps
        case .changeAllCaps(let isAllCaps):
            state.isAllCaps = isAllCaps
            state.title = isAllCaps ? state.title.uppercased() : state.title.lowercased()
        case .close:
            return .close
        }
        return nil
    }
}

private extension String {
    var isAllCaps: Bool {
        allSatisfy { character in
            character.isUppercase || !character.isCased
        }
    }
}

class SinkTrampoline: Equatable {
    private var sinks: [ObjectIdentifier: Any] = [:]

    func makeSink<Action, WorkflowType>(
        of actionType: Action.Type,
        with context: RenderContext<WorkflowType>
    ) -> StableSink<Action> where Action: WorkflowAction, Action.WorkflowType == WorkflowType {
        let sink = context.makeSink(of: actionType)

        sinks[ObjectIdentifier(actionType)] = sink

        return StableSink(trampoline: self)
    }

    func bounce<Action>(action: Action) {
        let sink = destination(for: Action.self)
        sink.send(action)
    }

    private func destination<Action>(for actionType: Action.Type) -> Sink<Action> {
        if let pipe = sinks[ObjectIdentifier(actionType)] {
            return pipe as! Sink<Action>
        }
        fatalError("bad plumbing")
    }

    static func == (lhs: SinkTrampoline, rhs: SinkTrampoline) -> Bool {
        lhs === rhs
    }
}

struct StableSink<Action>: Equatable {
    private var trampoline: SinkTrampoline

    init(trampoline: SinkTrampoline) {
        self.trampoline = trampoline
    }

    func send(_ action: Action) {
        trampoline.bounce(action: action)
    }
}

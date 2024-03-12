//
//  TwoCounterWorkflow.swift
//  Development-SwiftUITestbed
//
//  Created by Andrew Watt on 3/11/24.
//

import Foundation
import Workflow
import ComposableArchitecture
import SwiftUI

struct TwoCounterWorkflow: Workflow {

    @ObservableState
    struct State {}

    func makeInitialState() -> State {
        State()
    }

    enum Action: WorkflowAction {
        typealias WorkflowType = TwoCounterWorkflow

        func apply(toState state: inout TwoCounterWorkflow.State) -> Never? {
            return nil
        }
    }

    typealias Output = Never
    typealias Rendering = TwoCounterModel

    func render(state: State, context: RenderContext<TwoCounterWorkflow>) -> TwoCounterModel {
        let model: StoreModel<State, Action> = context.makeStoreModel(state: state)
        let counter1: CounterWorkflow.Model = CounterWorkflow().rendered(in: context, key: "1")
        let counter2: CounterWorkflow.Model = CounterWorkflow().rendered(in: context, key: "2")

        return TwoCounterModel(
            model: model,
            counter1: counter1,
            counter2: counter2
        )
    }
}


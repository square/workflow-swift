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
    struct State {
        var showSum = false
        var counterCount = 2
    }

    func makeInitialState() -> State {
        State()
    }

    struct ShowSumAction: WorkflowAction {
        typealias WorkflowType = TwoCounterWorkflow

        var showSum: Bool

        func apply(toState state: inout TwoCounterWorkflow.State) -> Never? {
            print("ShowSumAction: \(showSum)")
            state.showSum = showSum
            return nil
        }
    }

    enum CounterAction: WorkflowAction {
        typealias WorkflowType = TwoCounterWorkflow

        case addCounter

        func apply(toState state: inout TwoCounterWorkflow.State) -> Never? {
            switch self {
            case .addCounter:
                state.counterCount += 1
                return nil
            }
        }
    }

    typealias Output = Never
    typealias Rendering = TwoCounterModel

    func render(state: State, context: RenderContext<TwoCounterWorkflow>) -> TwoCounterModel {
        // TODO: dynamic collection of counters
        let counter1: CounterWorkflow.Model = CounterWorkflow().rendered(in: context, key: "1")
        let counter2: CounterWorkflow.Model = CounterWorkflow().rendered(in: context, key: "2")
        print("TwoCounterWorkflow render showSum: \(state.showSum)")
        let showSum = context.makeSink(of: ShowSumAction.self)
        let counterAction = context.makeSink(of: CounterAction.self)

        return TwoCounterModel(
            accessor: context.makeStateAccessor(state: state),
            counter1: counter1,
            counter2: counter2,
            onShowSumToggle: { showSum.send(ShowSumAction(showSum: $0)) },
            counterAction: counterAction
        )
    }
}

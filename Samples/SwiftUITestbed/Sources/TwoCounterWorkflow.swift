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
        var resetToken = CounterWorkflow.ResetToken()
    }

    func makeInitialState() -> State {
        State()
    }

    struct ResetAction: WorkflowAction {
        typealias WorkflowType = TwoCounterWorkflow

        var value: Int

        func apply(toState state: inout TwoCounterWorkflow.State) -> Never? {
            state.resetToken = .init(initialValue: value)
            return nil
        }
    }

    @CasePathable
    enum SumAction: WorkflowAction {
        typealias WorkflowType = TwoCounterWorkflow

        case showSum(Bool)

        func apply(toState state: inout TwoCounterWorkflow.State) -> Never? {
            switch self {
            case .showSum(let showSum):
                state.showSum = showSum
                return nil
            }
        }
    }

    enum CounterAction: WorkflowAction {
        typealias WorkflowType = TwoCounterWorkflow

        case addCounter
        case reset

        func apply(toState state: inout TwoCounterWorkflow.State) -> Never? {
            switch self {
            case .addCounter:
                state.counterCount += 1
                return nil
            case .reset:
                state.resetToken = CounterWorkflow.ResetToken()
                return nil
            }
        }
    }

    typealias Output = Never
    typealias Rendering = TwoCounterModel

    func render(state: State, context: RenderContext<TwoCounterWorkflow>) -> TwoCounterModel {
        // TODO: dynamic collection of counters
        let counter1: CounterWorkflow.Model = CounterWorkflow(resetToken: state.resetToken)
            .rendered(in: context, key: "1")
        let counter2: CounterWorkflow.Model = CounterWorkflow(resetToken: state.resetToken)
            .rendered(in: context, key: "2")

        print("TwoCounterWorkflow render")

        let sumAction = context.makeSink(of: SumAction.self)
        let counterAction = context.makeSink(of: CounterAction.self)
        let resetAction = context.makeSink(of: ResetAction.self)

        return TwoCounterModel(
            accessor: context.makeStateAccessor(state: state),
            counter1: counter1,
            counter2: counter2,
//            onShowSumToggle: { showSum.send(ShowSumAction(showSum: $0)) },
            sumAction: sumAction,
            counterAction: counterAction,
            resetAction: resetAction
        )
    }
}

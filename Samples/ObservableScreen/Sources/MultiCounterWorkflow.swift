import CasePaths
import Foundation
import SwiftUI
import Workflow
import WorkflowSwiftUI

struct MultiCounterWorkflow: Workflow {
    @ObservableState
    struct State {
        var showSum = false
        var showMax = false
        var counters: [CounterInfo] = []
        var max: CounterInfo = .init(name: "Max")
        var nextCounter = 1

        var resetToken = CounterWorkflow.ResetToken()

        mutating func addCounter() {
            counters += [.init(name: "Counter \(nextCounter)")]
            nextCounter += 1
        }
    }

    func makeInitialState() -> State {
        var state = State()
        state.addCounter()
        state.addCounter()
        return state
    }

    struct ResetAction: WorkflowAction {
        typealias WorkflowType = MultiCounterWorkflow

        func apply(toState state: inout MultiCounterWorkflow.State) -> Never? {
            state.resetToken = .init()
            return nil
        }
    }

    @CasePathable
    enum SumAction: WorkflowAction {
        typealias WorkflowType = MultiCounterWorkflow

        case showSum(Bool)

        func apply(toState state: inout MultiCounterWorkflow.State) -> Never? {
            switch self {
            case .showSum(let showSum):
                state.showSum = showSum
                return nil
            }
        }
    }

    enum CounterAction: WorkflowAction {
        typealias WorkflowType = MultiCounterWorkflow

        case addCounter
        case removeCounter(UUID)

        func apply(toState state: inout MultiCounterWorkflow.State) -> Never? {
            switch self {
            case .addCounter:
                state.addCounter()
                return nil
            case .removeCounter(let id):
                state.counters.removeAll { $0.id == id }
                return nil
            }
        }
    }

    typealias Output = Never
    typealias Rendering = MultiCounterModel

    func render(state: State, context: RenderContext<MultiCounterWorkflow>) -> Rendering {
        print("\(Self.self) rendered")

        let maxCounter: CounterWorkflow.Model? = if state.showMax {
            CounterWorkflow(
                info: state.max,
                resetToken: state.resetToken,
                initialValue: 5
            )
            .rendered(in: context, key: "max")
        } else {
            nil
        }

        let counters: [CounterWorkflow.Model] = state.counters.map { counter in
            CounterWorkflow(
                info: counter,
                resetToken: state.resetToken,
                maxValue: maxCounter?.count
            )
            .rendered(in: context, key: "\(counter.id)")
        }

        let sumAction = context.makeSink(of: SumAction.self)
        let counterAction = context.makeSink(of: CounterAction.self)
        let resetAction = context.makeSink(of: ResetAction.self)

        return MultiCounterModel(
            accessor: context.makeStateAccessor(state: state),
            counters: counters,
            maxCounter: maxCounter,
            sumAction: sumAction,
            counterAction: counterAction,
            resetAction: resetAction
        )
    }
}

struct MultiCounterModel: ObservableModel {
    typealias State = MultiCounterWorkflow.State

    let accessor: StateAccessor<State>

    let counters: [CounterWorkflow.Model]
    let maxCounter: CounterWorkflow.Model?

    let sumAction: Sink<MultiCounterWorkflow.SumAction>
    let counterAction: Sink<MultiCounterWorkflow.CounterAction>
    let resetAction: Sink<MultiCounterWorkflow.ResetAction>
}

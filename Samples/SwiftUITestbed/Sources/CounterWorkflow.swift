import Workflow
import ComposableArchitecture

struct CounterWorkflow: Workflow {

    var resetToken: ResetToken

    @ObservableState
    struct State {
        var count = 0
    }

    enum Action: WorkflowAction {
        typealias WorkflowType = CounterWorkflow

        case increment
        case decrement

        func apply(toState state: inout CounterWorkflow.State) -> CounterWorkflow.Output? {
            switch self {
            case .increment:
                state.count += 1
            case .decrement:
                state.count -= 1
            }
            return nil
        }
    }

    typealias Output = Never

    func makeInitialState() -> State {
        State(count: resetToken.initialValue)
    }

    func workflowDidChange(from previousWorkflow: CounterWorkflow, state: inout State) {
        if resetToken != previousWorkflow.resetToken {
            // this state reset will totally invalidate the body even if `count` doesn't change
            state = State(count: resetToken.initialValue)
        }
    }

    typealias Rendering = StoreModel<State, Action>
    typealias Model = StoreModel<State, Action>

    func render(state: State, context: RenderContext<CounterWorkflow>) -> StoreModel<State, Action> {
//        print("CounterWorkflow.render")
        return context.makeStoreModel(state: state)
    }
}

extension CounterWorkflow {
    struct ResetToken: Equatable {
        let id = UUID()
        var initialValue = 0
    }
}

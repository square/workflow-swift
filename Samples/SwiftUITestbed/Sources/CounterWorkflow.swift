import Workflow
import ComposableArchitecture

struct CounterWorkflow: Workflow {

    @ObservableState
    struct State {
        var count1 = 0
        var count2 = 0
    }

    enum Action: WorkflowAction {
        typealias WorkflowType = CounterWorkflow

        case increment(index: Int)
        case decrement(index: Int)

        func apply(toState state: inout CounterWorkflow.State) -> CounterWorkflow.Output? {
            switch self {
            case .increment(let index):
                if index == 0 {
                    state.count1 += 1
                } else {
                    state.count2 += 1
                }
            case .decrement(let index):
                if index == 0 {
                    state.count1 -= 1
                } else {
                    state.count2 -= 1
                }
            }
            return nil
        }
    }

    typealias Output = Never

    func makeInitialState() -> State {
        State()
    }

    typealias Rendering = StoreModel<State, Action>
    typealias Model = StoreModel<State, Action>

    func render(state: State, context: RenderContext<CounterWorkflow>) -> StoreModel<State, Action> {
        print("CounterWorkflow.render")
        return StoreModel(
            state: state,
            sendAction: context.makeSink(of: Action.self).send,
            sendValue: context.makeStateMutationSink().send
        )
    }
}

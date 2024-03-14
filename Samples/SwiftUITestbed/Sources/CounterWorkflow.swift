import Workflow
import ComposableArchitecture

struct CounterWorkflow: Workflow {

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
        State()
    }

    typealias Rendering = StoreModel<State, Action>
    typealias Model = StoreModel<State, Action>

    func render(state: State, context: RenderContext<CounterWorkflow>) -> StoreModel<State, Action> {
//        print("CounterWorkflow.render")
        return context.makeStoreModel(state: state)
    }
}

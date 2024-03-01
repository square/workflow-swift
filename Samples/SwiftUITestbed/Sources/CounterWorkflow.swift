import Workflow
import ComposableArchitecture

struct CounterWorkflow: Workflow {

    @ObservableState
    struct State {
        var count: Int
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
        State(count: 0)
    }

    typealias Rendering = CounterScreen

    func render(state: State, context: RenderContext<CounterWorkflow>) -> CounterScreen {
        print("CounterWorkflow.render")
        return CounterScreen(
            model: ViewModel(
                state: state,
                sendAction: context.makeSink(of: Action.self).send,
                sendValue: context.makeStateMutationSink().send
            )
        )
    }
}

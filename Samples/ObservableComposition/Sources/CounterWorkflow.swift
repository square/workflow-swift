import Foundation
import Workflow
import WorkflowSwiftUI
import WorkflowUI

struct CounterWorkflow: Workflow {
    // Dependencies from parent.
    let info: CounterInfo
    let resetToken: ResetToken
    let initialValue: Int
    let maxValue: Int?

    @ObservableState
    struct State {
        private var _count: Int

        var count: Int {
            get { _count }
            set {
                if let maxValue, newValue > maxValue {
                    _count = maxValue
                } else {
                    _count = newValue
                }
            }
        }

        var maxValue: Int? {
            didSet {
                guard let maxValue else { return }
                if count > maxValue {
                    count = maxValue
                }
            }
        }

        var info: CounterInfo

        init(count: Int, maxValue: Int? = nil, info: CounterInfo) {
            self._count = count
            self.maxValue = maxValue
            self.info = info
        }
    }

    enum Action: WorkflowAction {
        typealias WorkflowType = CounterWorkflow

        case increment
        case decrement

        func apply(toState state: inout CounterWorkflow.State) -> CounterWorkflow.Output? {
            switch self {
            case .increment:
                state.count += state.info.stepSize
            case .decrement:
                state.count -= state.info.stepSize
            }
            return nil
        }
    }

    typealias Output = Never

    init(info: CounterInfo, resetToken: ResetToken, initialValue: Int = 0, maxValue: Int? = nil) {
        self.info = info
        self.resetToken = resetToken
        self.initialValue = initialValue
        self.maxValue = maxValue
    }

    func makeInitialState() -> State {
        State(count: initialValue, maxValue: maxValue, info: info)
    }

    func workflowDidChange(from previousWorkflow: CounterWorkflow, state: inout State) {
        guard resetToken == previousWorkflow.resetToken else {
            // this state reset will totally invalidate the body even if `count` doesn't change
            state = makeInitialState()
            return
        }

        // CounterInfo is an @ObservableState dependency.
        // We can safely set it on every render and rely on Observation to handle change detection.
        state.info = info

        // maxValue is not observable. We should conditionally update it only on change.
        // Otherwise every set will trigger invalidation.
        if maxValue != previousWorkflow.maxValue {
            state.maxValue = maxValue
        }
    }

    typealias Rendering = ActionModel<State, Action>
    typealias Model = ActionModel<State, Action>

    func render(
        state: State,
        context: RenderContext<CounterWorkflow>
    ) -> ActionModel<State, Action> {
        print("\(Self.self) rendered \(state.info.name) count: \(state.count)")
        return context.makeActionModel(state: state)
    }
}

typealias CounterModel = CounterWorkflow.Model

@ObservableState
struct CounterInfo {
    let id = UUID()
    var name: String
    var stepSize = 1
}

extension CounterWorkflow {
    struct ResetToken: Equatable {
        let id = UUID()
    }
}

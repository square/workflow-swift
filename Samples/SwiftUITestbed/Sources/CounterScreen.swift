import SwiftUI
import MarketUI
import MarketWorkflowUI
import ViewEnvironment
import WorkflowUI
import Perception

struct CounterScreen: SwiftUIScreen, Screen {
    var model: Model
    
    typealias State = CounterWorkflow.State

    typealias Action = CounterWorkflow.Action

    static func makeView(store: Store<State, CounterWorkflow.Action>) -> some View {
        CounterScreenView(store: store)
    }
}

extension CounterScreen: MarketBackStackContentScreen {
    func backStackItem(in environment: ViewEnvironment) -> MarketUI.MarketNavigationItem {
        MarketNavigationItem(
            title: .text(.init(regular: "Counters")),
            backButton: .automatic()
        )
    }

    var backStackIdentifier: AnyHashable? { nil }
}

struct CounterScreenView: View {
    let store: Store<CounterWorkflow.State, CounterWorkflow.Action>

    var body: some View {
        WithPerceptionTracking {
            let _ = Self._printChanges()
            VStack {
                CounterView(store: store, index: 0)
                
                CounterView(store: store, index: 1)
            }
        }
    }
}

struct CounterView: View {
    let store: Store<CounterWorkflow.State, CounterWorkflow.Action>
    let index: Int

    var body: some View {
        let _ = print("Evaluating CounterView[\(index)].body")
        let _ = Self._printChanges()
        WithPerceptionTracking {
            let _ = print("Evaluating CounterView[\(index)].WithPerceptionTracking.body")
            let _ = Self._printChanges()
            HStack {
                Button {
                    store.send(.decrement(index: index))
                } label: {
                    Image(systemName: "minus")
                }

                Text("\(index == 0 ? store.count1 : store.count2)")
                    .monospacedDigit()

                Button {
                    store.send(.increment(index: index))
                } label: {
                    Image(systemName: "plus")
                }
            }
            .padding()
        }
    }
}

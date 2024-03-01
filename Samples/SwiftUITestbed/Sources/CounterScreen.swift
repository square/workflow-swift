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
        CounterView(store: store)
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

struct CounterView: View {
    let store: Store<CounterWorkflow.State, CounterWorkflow.Action>

    var body: some View {
        let _ = Self._printChanges()
        WithPerceptionTracking {
            HStack {
                Button {
                    store.send(.decrement)
                } label: {
                    Image(systemName: "minus")
                }

                Text("\(store.count)")
                    .monospacedDigit()

                Button {
                    store.send(.increment)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

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
    typealias Model = StoreModel<State, Action>

    static func makeView(store: Store<Model>) -> some View {
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
    typealias Model = StoreModel<CounterWorkflow.State, CounterWorkflow.Action>

    let store: Store<Model>

    var body: some View {
        WithPerceptionTracking {
            let _ = Self._printChanges()
            CounterView(store: store, index: 0)
        }
    }
}

struct CounterView: View {
    typealias Model = StoreModel<CounterWorkflow.State, CounterWorkflow.Action>
    let store: Store<Model>
    let index: Int

    var body: some View {
//        let _ = print("Evaluating CounterView[\(index)].body")
//        let _ = Self._printChanges()
        WithPerceptionTracking {
//            let _ = print("Evaluating CounterView[\(index)].WithPerceptionTracking.body")
//            let _ = Self._printChanges()
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
            .padding()
        }
    }
}

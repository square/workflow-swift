import SwiftUI
import ViewEnvironment
import WorkflowSwiftUI

struct CounterView: View {
    typealias Model = ActionModel<CounterWorkflow.State, CounterWorkflow.Action>

    let store: Store<Model>
    let key: String

    var body: some View {
        let _ = Self._printChanges()
        WithPerceptionTracking {
            let _ = print("Evaluated CounterView[\(key)] body")
            HStack {
                Text(store.info.name)

                Spacer()

                Button {
                    store.send(.decrement)
                } label: {
                    Image(systemName: "minus")
                }

                Text("\(store.boundedCount)")
                    .monospacedDigit()

                Button {
                    store.send(.increment)
                } label: {
                    Image(systemName: "plus")
                }

                if let maxValue = store.maxValue {
                    Text("(max \(maxValue))")
                }
            }
        }
    }
}

#if DEBUG

#Preview {
    CounterScreen.observableScreenPreview(
        state: .init(
            count: 0,
            info: .init(
                name: "Preview counter",
                stepSize: 1
            )
        )
    )
    .padding()
}

#endif

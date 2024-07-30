import SwiftUI
import ViewEnvironment
import WorkflowSwiftUI

struct CounterView: View {
    typealias Model = CounterModel

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

                Text("\(store.count)")
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
    CounterView(
        store: .preview(
            state: .init(
                count: 0,
                info: .init(
                    name: "Preview counter",
                    stepSize: 1
                )
            )
        ),
        key: "preview"
    )
    .padding()
}

#endif

import Foundation
import Perception
import SwiftUI
import ViewEnvironment
import Workflow
import WorkflowSwiftUI

struct MultiCounterView: View {
    @Perception.Bindable var store: Store<MultiCounterModel>

    var body: some View {
        WithPerceptionTracking {
            let _ = print("Evaluated MultiCounterView body")
            VStack {
                Text("Multi Counter Demo")
                    .font(.title)

                controls

                if let maxCounter = store.maxCounter {
                    CounterView(store: maxCounter, key: "max")
                }

                ForEach(
                    Array(store.counters.enumerated()),
                    id: \.element.id
                ) { index, counter in
                    HStack {
                        Button {
                            store.counterAction.send(.removeCounter(counter.info.id))
                        } label: {
                            Image(systemName: "xmark.circle")
                        }

                        CounterView(store: counter, key: "\(index)")
                    }
                    .padding(.vertical, 4)
                }

                // When showSum is false, changes to counters do not invalidate this body
                if store.showSum {
                    HStack {
                        Text("Sum")
                        Spacer()
                        Text("\(store.counters.map(\.boundedCount).reduce(0, +))")
                    }
                }

                Spacer()
            }
            .padding()
        }
    }

    @ViewBuilder
    var controls: some View {
        // Binding directly to state
        Toggle(
            "Show Max",
            isOn: $store.showMax
        )
        // Binding with a custom setter action
        ToggleWrapper(
            "Show Sum",
            isOn: $store.showSum.sending(sink: \.sumAction, action: \.showSum)
        )

        HStack {
            Button("Add Counter") {
                store.counterAction.send(.addCounter)
            }

            Button("Reset Counters") {
                // struct action
                store.resetAction.send(.init(value: 0))
            }
        }
        .buttonStyle(.bordered)
    }
}

struct ToggleWrapper: View {
    var name: String
    @Binding var isOn: Bool

    init(_ name: String, isOn: Binding<Bool>) {
        self.name = name
        self._isOn = isOn
    }

    var body: some View {
        WithPerceptionTracking {
            let _ = print("Evaluated ToggleWrapper body")

            Toggle("Show Sum", isOn: $isOn)
        }
    }
}

#if DEBUG

struct MultiCounterView_Previews: PreviewProvider {
    static var previews: some View {
        MultiCounterWorkflow()
            .mapRendering(MultiCounterScreen.init)
            .workflowPreview()
    }
}

#endif

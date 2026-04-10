import Foundation
import Observation
import SwiftUI
import ViewEnvironment
import Workflow
import WorkflowSwiftUI

@available(iOS 17, *)
struct NativeMultiCounterView: View {
    @SwiftUI.Bindable var store: Store<MultiCounterModel>

    var body: some View {
        let _ = print("Evaluated NativeMultiCounterView body")
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
                    Text("\(store.counters.map(\.count).reduce(0, +))")
                }
            }

            Spacer()
        }
        .padding()
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
                store.resetAction.send(.init())
            }
        }
        .buttonStyle(.bordered)
    }
}

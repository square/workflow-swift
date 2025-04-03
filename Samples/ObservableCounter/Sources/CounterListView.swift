import SwiftUI
import WorkflowSwiftUI

struct CounterListView: View {
    @Perception.Bindable
    var store: Store<CounterListModel>

    var body: some View {
        let _ = print("CounterListView.body")
        WithPerceptionTracking {
            VStack {
                ForEach(store.scope(collection: \.counters)) { counter in
                    @Perception.Bindable var counter = counter

                    WithPerceptionTracking {
                        let _ = print("CounterListView.body.ForEach.body")
                        SimpleCounterView(count: $counter.count)
                    }
                }
            }
        }
    }
}

import SwiftUI
import WorkflowSwiftUI

struct CounterListView: View {
    @Bindable
    var store: Store<CounterListModel>

    var body: some View {
        // These print statements show the effect of state changes on body evaluations.
        let _ = print("CounterListView.body")
        VStack {
            ForEach(store.scope(collection: \.counters)) { counter in
                @Bindable var counter = counter

                let _ = print("CounterListView.body.ForEach.body")
                SimpleCounterView(count: $counter.count)
            }
        }
    }
}

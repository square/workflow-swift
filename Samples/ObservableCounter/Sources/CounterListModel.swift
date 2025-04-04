import Foundation
import WorkflowSwiftUI

typealias CounterListModel = StateAccessor<CounterListState>

@ObservableState
struct CounterListState {
    var counters: [Counter]

    @ObservableState
    struct Counter: Identifiable {
        let id = UUID()
        var count: Int
    }
}

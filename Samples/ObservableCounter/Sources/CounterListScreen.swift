import SwiftUI
import WorkflowSwiftUI

struct CounterListScreen: ObservableScreen {
    let model: CounterListModel

    static func makeView(store: Store<CounterListModel>) -> some View {
        CounterListView(store: store)
    }
}

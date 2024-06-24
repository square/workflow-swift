import SwiftUI
import ViewEnvironment
import WorkflowSwiftUI
import WorkflowUI

struct CounterScreen: ObservableScreen, Screen {
    var model: Model

    typealias State = CounterWorkflow.State
    typealias Action = CounterWorkflow.Action
    typealias Model = ActionModel<State, Action>

    static func makeView(store: Store<Model>) -> some View {
        CounterView(store: store, key: "root")
    }
}

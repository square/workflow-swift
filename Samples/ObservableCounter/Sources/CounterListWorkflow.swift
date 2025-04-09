import Foundation
import SwiftUI
import Workflow
import WorkflowSwiftUI

struct CounterListWorkflow: Workflow {
    typealias State = CounterListState
    typealias Model = CounterListModel
    typealias Rendering = Model

    func makeInitialState() -> State {
        State(counters: [.init(count: 0), .init(count: 0), .init(count: 0)])
    }

    func render(
        state: State,
        context: RenderContext<CounterListWorkflow>
    ) -> Rendering {
        print("State: \(state.counters.map(\.count))")
        return context.makeStateAccessor(state: state)
    }
}

#Preview {
    CounterListWorkflow()
        .mapRendering(CounterListScreen.init)
        .workflowPreview()
}

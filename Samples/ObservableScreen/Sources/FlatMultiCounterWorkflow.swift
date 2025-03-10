import Foundation
import SwiftUI
import Workflow
import WorkflowSwiftUI

// typealias FlatMultiCounterModel = StateAccessor<FlatMultiCounterWorkflow.State>
typealias FlatMultiCounterModel = CustomModel

@ObservableState
struct FlatMultiCounterState {
    var items: [Counter]
    var one: Counter = .init(count: 0)

    @ObservableState
    struct Counter: Identifiable {
        let id = UUID()
        var count: Int
    }
}

struct FlatMultiCounterWorkflow: Workflow {
    func makeInitialState() -> State {
        State(items: [.init(count: 0)]) // , .init(count: 0), .init(count: 0)])
    }

    typealias State = FlatMultiCounterState
    typealias Model = FlatMultiCounterModel
    typealias Rendering = Model

    func render(
        state: State,
        context: RenderContext<FlatMultiCounterWorkflow>
    ) -> Rendering {
        print("State: \(state.items.map(\.count))")
//        return context.makeStateAccessor(state: state)
        let stateMutationSink = context.makeStateMutationSink()

        return CustomModel(
            accessor: context.makeStateAccessor(state: state),
            children: state.items.enumerated().map { index, counter in
                StateAccessor(state: counter) { send in
                    stateMutationSink.send { state in
                        send(&state.items[index])
                    }
                }
            }
        )
    }
}

typealias ChildModel = StateAccessor<FlatMultiCounterWorkflow.State.Counter>

struct CustomModel: ObservableModel {
    var accessor: StateAccessor<FlatMultiCounterWorkflow.State>
    var children: [ChildModel]
}

struct FlatMultiCounterScreen: ObservableScreen {
    let model: FlatMultiCounterModel

    static func makeView(store: Store<FlatMultiCounterModel>) -> some View {
        FlatMultiCounterView(store: store)
    }
}

struct FlatMultiCounterView: View {
    @Perception.Bindable
    var store: Store<FlatMultiCounterModel>

    var body: some View {
        let _ = Self._printChanges()
        WithPerceptionTracking {
            VStack {
                // doesn't work
                ForEach($store.items) { counter in
                    WithPerceptionTracking {
                        SimpleCounterView(count: counter.count)
                    }
                }

                // works
//                ForEach(
//                    Array($store.items.enumerated()),
//                    id: \.element.id
//                ) { index, counter in
//                    WithPerceptionTracking {
//                        SimpleCounterView(count: $store.items[index].count)
//                    }
//                }

                // works
//                ForEach(
//                    store.scope(collection: \.items)
//                ) { (@Perception.Bindable item: Store<StateAccessor<FlatMultiCounterState.Counter>>) in
//                    WithPerceptionTracking {
//                        SimpleCounterView(count: $item.count)
//                    }
//
//                }

                // works
//                ForEach($store.items.map { ($0, $0.count) }, id: \.0.id) { (counter, count) in
//                    WithPerceptionTracking {
//                        SimpleCounterView(count: count)
//                    }
//                }

                // doesn't work (text does not update)
//                let bindings: [Binding<FlatMultiCounterState.Counter>] = $store.items.map { $0 }
//                ForEach(
//                    bindings
//                ) { (counter: Binding<[FlatMultiCounterState.Counter].Element>) in
//                    WithPerceptionTracking {
//                        SimpleCounterView(count: counter.count)
//                    }
//                }

                // works
//                ForEach(store.children) { (@Perception.Bindable counter: Store<ChildModel>) in
//                    WithPerceptionTracking {
//                        SimpleCounterView(count: $counter.count)
//                    }
//                }

                // doesn't work (wants [Binding] not Binding<[]>)
//                SingleItem(items: $store.items) { item in
//                    SimpleCounterView(count: item.count)
//                }
            }
        }
    }
}

struct SingleItem<Item, Content: View>: View {
    var items: [Item]
    var content: (Item) -> Content

    init(items: [Item], content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        content(items[0])
    }
}

struct SimpleCounterView: View {
    @Binding
    var count: Int
//
//    var store: Store<ChildModel>

//    @Binding
//    var counter: FlatMultiCounterWorkflow.State.Counter

    var body: some View {
        WithPerceptionTracking {
            let _ = Self._printChanges()
            HStack {
                Button {
                    count -= 1
                } label: {
                    Image(systemName: "minus")
                }

                Text("\(getCount)")
                    .monospacedDigit()

                Button {
                    count += 1
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    var getCount: Int {
        print("about to read count")
        let value = $count.wrappedValue
        print("read count: \(value)")
        return value
    }
}

#Preview {
    FlatMultiCounterWorkflow()
        .mapRendering(FlatMultiCounterScreen.init)
        .workflowPreview()
}

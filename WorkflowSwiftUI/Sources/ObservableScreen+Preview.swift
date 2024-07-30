#if canImport(UIKit)
#if DEBUG

import Foundation
import SwiftUI
import Workflow
import WorkflowUI

public extension ObservableScreen {
    /// Generates a static preview of this screen type.
    ///
    /// Previews generated with this method are static and do not update state. To generate a
    /// stateful preview, instantiate a workflow and use one of the
    /// ``Workflow/Workflow/workflowPreview(customizeEnvironment:)`` methods.
    ///
    /// - Parameter makeModel: A closure to create the screen's model. The provided `context` param
    ///   is a convenience to generate dummy sinks and state accessors.
    /// - Returns: A View for previews.
    static func observableScreenPreview(makeModel: (StaticStorePreviewContext) -> Model) -> some View {
        let store = Store<Model>.preview(makeModel: makeModel)
        return Self.makeView(store: store)
    }

    /// Generates a static preview of this screen type.
    ///
    /// Previews generated with this method are static and do not update state. To generate a
    /// stateful preview, instantiate a workflow and use one of the
    /// ``Workflow/Workflow/workflowPreview(customizeEnvironment:)`` methods.
    ///
    /// - Parameter state: The state of the screen.
    /// - Returns: A View for previews.
    static func observableScreenPreview<S, A>(state: S) -> some View where Model == ActionModel<S, A> {
        observableScreenPreview { context in
            context.makeActionModel(state: state)
        }
    }

    /// Generates a static preview of this screen type.
    ///
    /// Previews generated with this method are static and do not update state. To generate a
    /// stateful preview, instantiate a workflow and use one of the
    /// ``Workflow/Workflow/workflowPreview(customizeEnvironment:)`` methods.
    ///
    /// - Parameter state: The state of the screen.
    /// - Returns: A View for previews.
    static func observableScreenPreview<S>(state: S) -> some View where Model == StateAccessor<S> {
        observableScreenPreview { context in
            context.makeStateAccessor(state: state)
        }
    }
}

// MARK: - Preview previews

@ObservableState
private struct PreviewDemoState {
    var name = "Test"
    var count = 0
}

private struct PreviewDemoTrivialScreen: ObservableScreen {
    typealias Model = StateAccessor<PreviewDemoState>

    var model: Model

    static func makeView(store: Store<Model>) -> some View {
        PreviewDemoView(store: store)
    }

    struct PreviewDemoView: View {
        let store: Store<Model>

        var body: some View {
            VStack {
                Text("\(store.name)")
                Button("Add", systemImage: "add") {
                    store.count += 1
                }
                Button("Reset") {
                    store.count = 0
                }
            }
        }
    }
}

private enum PreviewDemoAction {}

private struct PreviewDemoActionScreen: ObservableScreen {
    typealias Model = ActionModel<PreviewDemoState, PreviewDemoAction>

    var model: Model

    static func makeView(store: Store<Model>) -> some View {
        PreviewDemoView(store: store)
    }

    struct PreviewDemoView: View {
        let store: Store<Model>

        var body: some View {
            VStack {
                Text("\(store.name)")
                Button("Add", systemImage: "add") {
                    store.count += 1
                }
                Button("Reset") {
                    store.count = 0
                }
            }
        }
    }
}

private enum PreviewDemoAction2 {}

private struct PreviewDemoComplexModel: ObservableModel {
    var accessor: StateAccessor<PreviewDemoState>

    var sink: Sink<PreviewDemoAction>
    var sink2: Sink<PreviewDemoAction2>
}

private struct PreviewDemoComplexScreen: ObservableScreen {
    typealias Model = PreviewDemoComplexModel

    var model: Model

    static func makeView(store: Store<Model>) -> some View {
        PreviewDemoView(store: store)
    }

    struct PreviewDemoView: View {
        let store: Store<Model>

        var body: some View {
            VStack {
                Text("\(store.name)")
                Button("Add", systemImage: "add") {
                    store.count += 1
                }
                Button("Reset") {
                    store.count = 0
                }
            }
        }
    }
}

struct PreviewDemoScreen_Preview: PreviewProvider {
    static var previews: some View {
        PreviewDemoTrivialScreen
            .observableScreenPreview(state: .init())
            .previewDisplayName("Trivial Screen")

        PreviewDemoActionScreen
            .observableScreenPreview(state: .init())
            .previewDisplayName("Single Action Screen")

        PreviewDemoComplexScreen
            .observableScreenPreview { context in
                PreviewDemoComplexModel(
                    accessor: context.makeStateAccessor(state: .init()),
                    sink: context.makeSink(of: PreviewDemoAction.self),
                    sink2: context.makeSink(of: PreviewDemoAction2.self)
                )
            }
            .previewDisplayName("Custom Model Screen")
    }
}

#endif
#endif

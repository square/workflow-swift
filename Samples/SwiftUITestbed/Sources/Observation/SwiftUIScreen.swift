#if canImport(UIKit)

import ComposableArchitecture // for ObservableState
import SwiftUI
import Workflow
import WorkflowUI

struct ViewModel<State: ObservableState, Action> {
    let state: State
    let sendAction: (Action) -> Void
}

protocol SwiftUIScreen: Screen {
    associatedtype State: ObservableState
    associatedtype Action
    associatedtype Content: View

    var state: State { get }
    var sendAction: (Action) -> Void { get }

    @ViewBuilder
    static func makeView(store: Store<State>, sendAction: @escaping (Action) -> Void) -> Content
}

extension SwiftUIScreen {
    func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
        ViewControllerDescription(
            type: ModeledHostingController<Self.State, EnvironmentInjectingView<Content>>.self,
            environment: environment,
            build: {
                let (store, setState) = Store.make(initialState: state)
                return ModeledHostingController(
                    setState: setState,
                    rootView: EnvironmentInjectingView(
                        environment: environment,
                        content: Self.makeView(
                            store: store,
                            sendAction: { _ in
                                fatalError("TODO")
                            }
                        )
                    )
                )
            },
            update: { hostingController in
                hostingController.setState(state)
                // TODO: update viewEnvironment
            }
        )
    }
}

private struct EnvironmentInjectingView<Content: View>: View {
    var environment: ViewEnvironment
    let content: Content

    var body: some View {
        content
            .environment(\.viewEnvironment, environment)
    }
}

private final class ModeledHostingController<State, Content: View>: UIHostingController<Content> {
    let setState: (State) -> Void

    init(setState: @escaping (State) -> Void, rootView: Content) {
        self.setState = setState
        super.init(rootView: rootView)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("not implemented")
    }
}

#endif

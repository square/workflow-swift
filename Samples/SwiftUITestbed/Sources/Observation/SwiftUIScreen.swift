#if canImport(UIKit)

import ComposableArchitecture // for ObservableState
import SwiftUI
import Workflow
import WorkflowUI

protocol SwiftUIScreen: Screen {
//    associatedtype State: ObservableState
//    associatedtype Action
    associatedtype Content: View
    associatedtype Model: ObservableModel

    var model: Model { get }

    @ViewBuilder
    static func makeView(store: Store<Model>) -> Content
}

extension SwiftUIScreen {
    func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
        ViewControllerDescription(
            type: ModeledHostingController<Model, EnvironmentInjectingView<Content>>.self,
            environment: environment,
            build: {
                let (store, setModel) = Store.make(model: model)
                return ModeledHostingController(
                    setModel: setModel,
                    rootView: EnvironmentInjectingView(
                        environment: environment,
                        content: Self.makeView(store: store)
                    )
                )
            },
            update: { hostingController in
                hostingController.setModel(model)
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

private final class ModeledHostingController<Model, Content: View>: UIHostingController<Content> {
    let setModel: (Model) -> Void

    init(setModel: @escaping (Model) -> Void, rootView: Content) {
        self.setModel = setModel
        super.init(rootView: rootView)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("not implemented")
    }
}

#endif

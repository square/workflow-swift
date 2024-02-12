#if canImport(Observation) && canImport(UIKit)
    import Observation

import SwiftUI
import Workflow
import WorkflowUI

@available(iOS 17, macOS 14.0, *)
public protocol ObservableSwiftUIScreen: Screen {
    associatedtype Content: View

    @ViewBuilder
    static func makeView(model: ObservableValue<Self>) -> Content

    static var isDuplicate: ((Self, Self) -> Bool)? { get }
}

@available(iOS 17, macOS 14.0, *)
public extension ObservableSwiftUIScreen {
    static var isDuplicate: ((Self, Self) -> Bool)? { return nil }
}

@available(iOS 17, macOS 14.0, *)
public extension ObservableSwiftUIScreen where Self: Equatable {
    static var isDuplicate: ((Self, Self) -> Bool)? { { $0 == $1 } }
}

@available(iOS 17, macOS 14.0, *)
public extension ObservableSwiftUIScreen {
    func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
        ViewControllerDescription(
            type: ModeledHostingController<Self, EnvironmentInjectingView<Content>>.self,
            environment: environment,
            build: {
                let (model, modelSink) = ObservableValue.makeObservableValue(self, isDuplicate: Self.isDuplicate)
                let (viewEnvironment, envSink) = ObservableValue.makeObservableValue(environment)
                return ModeledHostingController(
                    modelSink: modelSink,
                    viewEnvironmentSink: envSink,
                    rootView: EnvironmentInjectingView(
                            viewEnvironment: viewEnvironment,
                            content: Self.makeView(model: model)
                        )
                )
            },
            update: {
                $0.modelSink.send(self)
                $0.viewEnvironmentSink.send(environment)
            }
        )
    }
}

@available(iOS 17, macOS 14.0, *)
private struct EnvironmentInjectingView<Content: View>: View {
    var viewEnvironment: ObservableValue<ViewEnvironment>
    let content: Content

    var body: some View {
        content
            .environment(\.viewEnvironment, viewEnvironment.value)
    }
}
#endif

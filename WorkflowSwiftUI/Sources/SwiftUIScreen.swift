/*
 * Copyright 2023 Square Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#if canImport(UIKit)

import SwiftUI
import Workflow
import WorkflowUI

public protocol SwiftUIScreen: Screen {
    associatedtype Content: View

    @ViewBuilder
    static func makeView(model: ObservableObjectValue<Self>) -> Content

    static var isDuplicate: ((Self, Self) -> Bool)? { get }
}

public extension SwiftUIScreen {
    static var isDuplicate: ((Self, Self) -> Bool)? { return nil }
}

public extension SwiftUIScreen where Self: Equatable {
    static var isDuplicate: ((Self, Self) -> Bool)? { { $0 == $1 } }
}

public extension SwiftUIScreen {
    func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
        ViewControllerDescription(
            type: ModeledHostingController<Self, WithModel<Self, EnvironmentInjectingView<Content>>>.self,
            environment: environment,
            build: {
                let (model, modelSink) = ObservableObjectValue.makeObservableValue(self, isDuplicate: Self.isDuplicate)
                let (viewEnvironment, envSink) = ObservableObjectValue.makeObservableValue(environment)
                return ModeledHostingController(
                    modelSink: modelSink,
                    viewEnvironmentSink: envSink,
                    rootView: WithModel(model, content: { model in
                        EnvironmentInjectingView(
                            viewEnvironment: viewEnvironment,
                            content: Self.makeView(model: model)
                        )
                    })
                )
            },
            update: {
                $0.modelSink.send(self)
                $0.viewEnvironmentSink.send(environment)
            }
        )
    }
}

private struct EnvironmentInjectingView<Content: View>: View {
    @ObservedObject var viewEnvironment: ObservableObjectValue<ViewEnvironment>
    let content: Content

    var body: some View {
        content
            .environment(\.viewEnvironment, viewEnvironment.value)
    }
}

final class ModeledHostingController<Model, Content: View>: UIHostingController<Content> {
    let modelSink: Sink<Model>
    let viewEnvironmentSink: Sink<ViewEnvironment>

    init(modelSink: Sink<Model>, viewEnvironmentSink: Sink<ViewEnvironment>, rootView: Content) {
        self.modelSink = modelSink
        self.viewEnvironmentSink = viewEnvironmentSink

        super.init(rootView: rootView)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("not implemented")
    }
}

#endif

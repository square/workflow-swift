/*
 * Copyright 2022 Square Inc.
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

#if canImport(SwiftUI) && canImport(UIKit) && canImport(Combine) && swift(>=5.1)

    import Combine
    import SwiftUI
    import Workflow
    import WorkflowUI

    @available(iOS 13.0, macOS 10.15, *)
    public protocol SwiftUIScreen: Screen {
        associatedtype Content: View

        @ViewBuilder
        static func makeView(model: ObservableValue<Self>) -> Content

        static var isDuplicate: ((Self, Self) -> Bool)? { get }
    }

    @available(iOS 13.0, macOS 10.15, *)
    public extension SwiftUIScreen {
        static var isDuplicate: ((Self, Self) -> Bool)? { return nil }
    }

    @available(iOS 13.0, macOS 10.15, *)
    public extension SwiftUIScreen where Self: Equatable {
        static var isDuplicate: ((Self, Self) -> Bool)? { { $0 == $1 } }
    }

    @available(iOS 13.0, macOS 10.15, *)
    public extension SwiftUIScreen {
        func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
            ViewControllerDescription(
                type: ModeledHostingController<Self, WithModel<Self, EnvironmentInjectingView<Content>>>.self,
                build: {
                    let (model, modelSink) = ObservableValue.makeObservableValue(value: self, isDuplicate: Self.isDuplicate)
                    let (viewEnvironment, envSink) = ObservableValue.makeObservableValue(value: environment)
                    return ModeledHostingController(
                        modelSink: modelSink,
                        viewEnvironmentSink: envSink,
                        rootView: WithModel(model: model, content: { model in
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

    @available(iOS 13.0, macOS 10.15, *)
    public struct WithModel<Model, Content: View>: View {
        @ObservedObject private var model: ObservableValue<Model>
        private let content: (ObservableValue<Model>) -> Content

        public init(
            model: ObservableValue<Model>,
            @ViewBuilder content: @escaping (ObservableValue<Model>) -> Content
        ) {
            self.model = model
            self.content = content
        }

        public var body: Content {
            content(model)
        }
    }

    @available(iOS 13.0, macOS 10.15, *)
    private struct EnvironmentInjectingView<Content: View>: View {
        @ObservedObject var viewEnvironment: ObservableValue<ViewEnvironment>
        let content: Content

        var body: some View {
            content
                .environment(\.viewEnvironment, viewEnvironment.value)
        }
    }

    @available(iOS 13.0, macOS 10.15, *)
    private final class ModeledHostingController<Model, Content: View>: UIHostingController<Content> {
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

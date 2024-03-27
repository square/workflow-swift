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
    static func makeView(model: ObservableValue<Self>) -> Content

    static var sizingOptions: SwiftUIScreenSizingOptions { get }

    static var isEquivalent: ((Self, Self) -> Bool)? { get }
}

public extension SwiftUIScreen {
    static var sizingOptions: SwiftUIScreenSizingOptions { [] }
}

public extension SwiftUIScreen {
    static var isEquivalent: ((Self, Self) -> Bool)? { nil }
}

public extension SwiftUIScreen where Self: Equatable {
    static var isEquivalent: ((Self, Self) -> Bool)? { { $0 == $1 } }
}

public extension SwiftUIScreen {
    func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
        ViewControllerDescription(
            type: ModeledHostingController<Self, WithModel<Self, EnvironmentInjectingView<Content>>>.self,
            environment: environment,
            build: {
                let (model, modelSink) = ObservableValue.makeObservableValue(self, isEquivalent: Self.isEquivalent)
                let (viewEnvironment, envSink) = ObservableValue.makeObservableValue(environment)
                return ModeledHostingController(
                    swiftUIScreenSizingOptions: Self.sizingOptions,
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

public struct SwiftUIScreenSizingOptions: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let preferredContentSize: SwiftUIScreenSizingOptions = .init(rawValue: 1 << 0)
}

private struct EnvironmentInjectingView<Content: View>: View {
    @ObservedObject var viewEnvironment: ObservableValue<ViewEnvironment>
    let content: Content

    var body: some View {
        content
            .environment(\.viewEnvironment, viewEnvironment.value)
    }
}

private final class ModeledHostingController<Model, Content: View>: UIHostingController<Content> {
    let swiftUIScreenSizingOptions: SwiftUIScreenSizingOptions
    let modelSink: Sink<Model>
    let viewEnvironmentSink: Sink<ViewEnvironment>

    init(
        swiftUIScreenSizingOptions: SwiftUIScreenSizingOptions,
        modelSink: Sink<Model>,
        viewEnvironmentSink: Sink<ViewEnvironment>,
        rootView: Content
    ) {
        self.swiftUIScreenSizingOptions = swiftUIScreenSizingOptions
        self.modelSink = modelSink
        self.viewEnvironmentSink = viewEnvironmentSink

        super.init(rootView: rootView)

        // TODO: This solution seems to cause Market's Modals framework to animate presentation incorrectly.
        if #available(iOS 16.0, *) {
            self.sizingOptions = swiftUIScreenSizingOptions.uiHostingControllerSizingOptions
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("not implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear

        if #available(iOS 16.0, *),
            swiftUIScreenSizingOptions.contains(.preferredContentSize) {
            // Without manually calling setNeedsLayout here it was observed that a call to
            // layoutIfNeeded() immediately after loading the view would not perform a layout, and
            // therefore would not update the preferredContentSize on the first layout in
            // viewDidLayoutSubviews() below.
            view.setNeedsLayout()
        }
    }

    private var hasLaidOutOnce = false
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        defer { hasLaidOutOnce = true }

        if #available(iOS 16.0, *) {
            // Handled in initializer, but set it on first layout to resolve a bug where the PCS is
            // not updated appropriately after the first layout.
            if !hasLaidOutOnce,
                swiftUIScreenSizingOptions.contains(.preferredContentSize) {
                let size = view.sizeThatFits(view.frame.size)

                if preferredContentSize != size {
                    preferredContentSize = size
                }
            }
        } else if !swiftUIScreenSizingOptions.isEmpty {
            if swiftUIScreenSizingOptions.contains(.preferredContentSize) {
                let size = view.sizeThatFits(view.frame.size)

                if preferredContentSize != size {
                    preferredContentSize = size
                }
            }
        }
    }
}

extension SwiftUIScreenSizingOptions {
    @available(iOS 16.0, *)
    fileprivate var uiHostingControllerSizingOptions: UIHostingControllerSizingOptions {
        var options = UIHostingControllerSizingOptions()

        if contains(.preferredContentSize) {
            options.insert(.preferredContentSize)
        }

        return options
    }
}

#endif

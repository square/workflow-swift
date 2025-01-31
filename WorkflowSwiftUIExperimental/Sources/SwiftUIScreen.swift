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

    var sizingOptions: SwiftUIScreenSizingOptions { get }

    @ViewBuilder
    static func makeView(model: ObservableValue<Self>) -> Content

    static var isEquivalent: ((Self, Self) -> Bool)? { get }
}

extension SwiftUIScreen {
    public var sizingOptions: SwiftUIScreenSizingOptions { [] }
}

extension SwiftUIScreen {
    public static var isEquivalent: ((Self, Self) -> Bool)? { nil }
}

extension SwiftUIScreen where Self: Equatable {
    public static var isEquivalent: ((Self, Self) -> Bool)? { { $0 == $1 } }
}

extension SwiftUIScreen {
    public func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
        ViewControllerDescription(
            type: ModeledHostingController<Self, WithModel<Self, EnvironmentInjectingView<Content>>>.self,
            environment: environment,
            build: {
                let (model, modelSink) = ObservableValue.makeObservableValue(self, isEquivalent: Self.isEquivalent)
                let (viewEnvironment, envSink) = ObservableValue.makeObservableValue(environment)
                return ModeledHostingController(
                    modelSink: modelSink,
                    viewEnvironmentSink: envSink,
                    rootView: WithModel(model, content: { model in
                        EnvironmentInjectingView(
                            viewEnvironment: viewEnvironment,
                            content: Self.makeView(model: model)
                        )
                    }),
                    swiftUIScreenSizingOptions: sizingOptions
                )
            },
            update: {
                $0.modelSink.send(self)
                $0.swiftUIScreenSizingOptions = sizingOptions
                // ViewEnvironment updates are handled by the ModeledHostingController internally
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

private final class ModeledHostingController<Model, Content: View>: UIHostingController<Content>, ViewEnvironmentObserving {
    let modelSink: Sink<Model>
    let viewEnvironmentSink: Sink<ViewEnvironment>
    var swiftUIScreenSizingOptions: SwiftUIScreenSizingOptions {
        didSet {
            updateSizingOptionsIfNeeded()
            if isViewLoaded {
                setNeedsLayoutBeforeFirstLayoutIfNeeded()
            }
        }
    }

    private var hasLaidOutOnce = false
    private var maxFrameWidth: CGFloat = 0
    private var maxFrameHeight: CGFloat = 0

    init(
        modelSink: Sink<Model>,
        viewEnvironmentSink: Sink<ViewEnvironment>,
        rootView: Content,
        swiftUIScreenSizingOptions: SwiftUIScreenSizingOptions
    ) {
        self.modelSink = modelSink
        self.viewEnvironmentSink = viewEnvironmentSink
        self.swiftUIScreenSizingOptions = swiftUIScreenSizingOptions

        super.init(rootView: rootView)

        updateSizingOptionsIfNeeded()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("not implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // `UIHostingController` provides a system background color by default. We set the
        // background to clear to support contexts where it is composed within another view
        // controller.
        view.backgroundColor = .clear

        setNeedsLayoutBeforeFirstLayoutIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        defer { hasLaidOutOnce = true }

        if swiftUIScreenSizingOptions.contains(.preferredContentSize) {
            // Use the largest frame ever laid out in as a constraint for preferredContentSize
            // measurements.
            let width = max(view.frame.width, maxFrameWidth)
            let height = max(view.frame.height, maxFrameHeight)

            maxFrameWidth = width
            maxFrameHeight = height

            let fixedSize = CGSize(width: width, height: height)

            // Measure a few different ways to account for ScrollView behavior. ScrollViews will
            // always greedily fill the space available, but will report the natural content size
            // when given an infinite size. By combining the results of these measurements we can
            // deduce the natural size of content that scrolls in either direction, or both, or
            // neither.

            let fixedResult = view.sizeThatFits(fixedSize)
            let unboundedHorizontalResult = view.sizeThatFits(CGSize(width: .infinity, height: fixedSize.height))
            let unboundedVerticalResult = view.sizeThatFits(CGSize(width: fixedSize.width, height: .infinity))

            let size = CGSize(
                width: min(fixedResult.width, unboundedHorizontalResult.width),
                height: min(fixedResult.height, unboundedVerticalResult.height)
            )

            if preferredContentSize != size {
                preferredContentSize = size
            }
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        applyEnvironmentIfNeeded()
    }

    private func updateSizingOptionsIfNeeded() {
        if !swiftUIScreenSizingOptions.contains(.preferredContentSize),
           preferredContentSize != .zero
        {
            preferredContentSize = .zero
        }
    }

    private func setNeedsLayoutBeforeFirstLayoutIfNeeded() {
        if swiftUIScreenSizingOptions.contains(.preferredContentSize), !hasLaidOutOnce {
            // Without manually calling setNeedsLayout here it was observed that a call to
            // layoutIfNeeded() immediately after loading the view would not perform a layout, and
            // therefore would not update the preferredContentSize in viewDidLayoutSubviews().
            // UI-5797
            view.setNeedsLayout()
        }
    }

    // MARK: ViewEnvironmentObserving

    func apply(environment: ViewEnvironment) {
        viewEnvironmentSink.send(environment)
    }
}

#endif

/*
 * Copyright 2020 Square Inc.
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

#if canImport(SwiftUI) && canImport(Combine)

import Combine
import ReactiveSwift
import SwiftUI
import Workflow

/// Hosts a Workflow-powered view hierarchy.
///
/// Example:
///
/// ```
/// var body: some View {
///     WorkflowView(workflow: MyWorkflow(), onOutput: { self.handleOutput($0) }) { rendering in
///         VStack {
///
///             Text("The value is \(rendering.value)")
///
///             Button(action: rendering.onIncrement) {
///                 Text("+")
///             }
///
///             Button(action: rendering.onDecrement) {
///                 Text("-")
///             }
///
///         }
///     }
/// }
/// ```
@available(*, deprecated, message: "Use ObservableScreen to render SwiftUI content")
public struct WorkflowView<T: Workflow, Content: View>: View {
    /// The workflow implementation to use
    public var workflow: T

    /// A handler for any output events emitted by the workflow
    public var onOutput: (T.Output) -> Void

    /// A closure that maps the workflow's rendering type into a view of type `Content`.
    public var content: (T.Rendering) -> Content

    public init(workflow: T, onOutput: @escaping (T.Output) -> Void, content: @escaping (T.Rendering) -> Content) {
        self.onOutput = onOutput
        self.content = content
        self.workflow = workflow
    }

    public var body: some View {
        IntermediateView(
            workflow: workflow,
            onOutput: onOutput,
            content: content
        )
    }
}

@available(*, deprecated, message: "Use ObservableScreen to render SwiftUI content")
public extension WorkflowView where T.Output == Never {
    /// Convenience initializer for workflows with no output.
    init(workflow: T, content: @escaping (T.Rendering) -> Content) {
        self.init(workflow: workflow, onOutput: { _ in }, content: content)
    }
}

@available(*, deprecated, message: "Use ObservableScreen to render SwiftUI content")
public extension WorkflowView where T.Rendering == Content {
    /// Convenience initializer for workflows whose rendering type conforms to `View`.
    init(workflow: T, onOutput: @escaping (T.Output) -> Void) {
        self.init(workflow: workflow, onOutput: onOutput, content: { $0 })
    }
}

@available(*, deprecated, message: "Use ObservableScreen to render SwiftUI content")
public extension WorkflowView where T.Output == Never, T.Rendering == Content {
    /// Convenience initializer for workflows with no output whose rendering type conforms to `View`.
    init(workflow: T) {
        self.init(workflow: workflow, onOutput: { _ in }, content: { $0 })
    }
}

// We use a `UIViewController/UIViewControllerRepresentable` here to drop back to UIKit because it gives us a predictable
// update mechanism via `updateUIViewController(_:context:)`. If we were to manage a `WorkflowHost` instance directly
// within a SwiftUI view we would need to update the host with the updated workflow from our implementation of `body`.
// Performing work within the body accessor is strongly discouraged, so we jump back into UIKit for a second here.
fileprivate struct IntermediateView<T: Workflow, Content: View> {
    var workflow: T
    var onOutput: (T.Output) -> Void
    var content: (T.Rendering) -> Content
}

#if canImport(UIKit)

import UIKit

extension IntermediateView: UIViewControllerRepresentable {
    func makeUIViewController(context: UIViewControllerRepresentableContext<IntermediateView<T, Content>>) -> WorkflowHostingViewController<T, Content> {
        WorkflowHostingViewController(workflow: workflow, content: content)
    }

    func updateUIViewController(_ uiViewController: WorkflowHostingViewController<T, Content>, context: UIViewControllerRepresentableContext<IntermediateView<T, Content>>) {
        uiViewController.content = content
        uiViewController.onOutput = onOutput
        uiViewController.update(to: workflow)
    }
}

fileprivate final class WorkflowHostingViewController<T: Workflow, Content: View>: UIViewController {
    private let workflowHost: WorkflowHost<T>
    private let hostingController: UIHostingController<RootView<Content>>
    private let rootViewProvider: RootViewProvider<Content>

    var content: (T.Rendering) -> Content
    var onOutput: (T.Output) -> Void

    private let (lifetime, token) = Lifetime.make()

    init(workflow: T, content: @escaping (T.Rendering) -> Content) {
        self.content = content
        self.onOutput = { _ in }

        self.workflowHost = WorkflowHost(workflow: workflow)
        self.rootViewProvider = RootViewProvider(view: content(workflowHost.rendering.value))
        self.hostingController = UIHostingController(rootView: RootView(provider: rootViewProvider))

        super.init(nibName: nil, bundle: nil)

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        workflowHost
            .rendering
            .signal
            .take(during: lifetime)
            .observeValues { [weak self] rendering in
                self?.didEmit(rendering: rendering)
            }

        workflowHost
            .output
            .take(during: lifetime)
            .observeValues { [weak self] output in
                self?.didEmit(output: output)
            }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        hostingController.view.frame = view.bounds
    }

    private func didEmit(rendering: T.Rendering) {
        rootViewProvider.view = content(rendering)
    }

    private func didEmit(output: T.Output) {
        onOutput(output)
    }

    func update(to workflow: T) {
        workflowHost.update(workflow: workflow)
    }
}

#elseif canImport(AppKit)

import AppKit

@available(OSX 10.15, *)
extension IntermediateView: NSViewControllerRepresentable {
    func makeNSViewController(context: NSViewControllerRepresentableContext<IntermediateView<T, Content>>) -> WorkflowHostingViewController<T, Content> {
        WorkflowHostingViewController(workflow: workflow, content: content)
    }

    func updateNSViewController(_ nsViewController: WorkflowHostingViewController<T, Content>, context: NSViewControllerRepresentableContext<IntermediateView<T, Content>>) {
        nsViewController.content = content
        nsViewController.onOutput = onOutput
        nsViewController.update(to: workflow)
    }
}

@available(macOS 10.15, *)
fileprivate final class WorkflowHostingViewController<T: Workflow, Content: View>: NSViewController {
    private let workflowHost: WorkflowHost<T>
    private let hostingController: NSHostingController<RootView<Content>>
    private let rootViewProvider: RootViewProvider<Content>

    var content: (T.Rendering) -> Content
    var onOutput: (T.Output) -> Void

    private let (lifetime, token) = Lifetime.make()

    init(workflow: T, content: @escaping (T.Rendering) -> Content) {
        self.content = content
        self.onOutput = { _ in }

        self.workflowHost = WorkflowHost(workflow: workflow)
        self.rootViewProvider = RootViewProvider(view: content(workflowHost.rendering.value))
        self.hostingController = NSHostingController(rootView: RootView(provider: rootViewProvider))

        super.init(nibName: nil, bundle: nil)

        addChild(hostingController)

        workflowHost
            .rendering
            .signal
            .take(during: lifetime)
            .observeValues { [weak self] rendering in
                self?.didEmit(rendering: rendering)
            }

        workflowHost
            .output
            .take(during: lifetime)
            .observeValues { [weak self] output in
                self?.didEmit(output: output)
            }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(hostingController.view)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        hostingController.view.frame = view.bounds
    }

    private func didEmit(rendering: T.Rendering) {
        rootViewProvider.view = content(rendering)
    }

    private func didEmit(output: T.Output) {
        onOutput(output)
    }

    func update(to workflow: T) {
        workflowHost.update(workflow: workflow)
    }
}

#endif

// Assigning `rootView` on a `UIHostingController` causes unwanted animated transitions.
// To avoid this, we never change the root view, but we pass down an `ObservableObject`
// so that we can still update the hierarchy as the workflow emits new renderings.
fileprivate final class RootViewProvider<T: View>: ObservableObject {
    @Published var view: T

    init(view: T) {
        self.view = view
    }
}

fileprivate struct RootView<T: View>: View {
    @ObservedObject var provider: RootViewProvider<T>

    var body: some View {
        provider.view
    }
}

#endif

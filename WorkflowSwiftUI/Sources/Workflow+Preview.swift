#if canImport(UIKit)
#if DEBUG

import Foundation
import ReactiveSwift
import SwiftUI
import Workflow
import WorkflowUI

public extension Workflow where Rendering: Screen {
    func workflowPreview(
        customizeEnvironment: @escaping (inout ViewEnvironment) -> Void = { _ in },
        onOutput: @escaping (Output) -> Void
    ) -> some View {
        PreviewView(
            workflow: self,
            customizeEnvironment: customizeEnvironment,
            onOutput: onOutput
        )
        .ignoresSafeArea()
    }
}

public extension Workflow where Rendering: Screen, Output == Never {
    func workflowPreview(
        customizeEnvironment: @escaping (inout ViewEnvironment) -> Void = { _ in }
    ) -> some View {
        PreviewView(
            workflow: self,
            customizeEnvironment: customizeEnvironment,
            onOutput: { _ in }
        )
        .ignoresSafeArea()
    }
}

private struct PreviewView<WorkflowType: Workflow>: UIViewControllerRepresentable where WorkflowType.Rendering: Screen {
    typealias ScreenType = WorkflowType.Rendering
    typealias UIViewControllerType = WorkflowHostingController<ScreenType, WorkflowType.Output>

    let workflow: WorkflowType
    let customizeEnvironment: (inout ViewEnvironment) -> Void
    let onOutput: (WorkflowType.Output) -> Void

    func makeUIViewController(context: Context) -> UIViewControllerType {
        let controller = WorkflowHostingController(
            workflow: workflow,
            customizeEnvironment: customizeEnvironment
        )
        let coordinator = context.coordinator

        coordinator.outputDisposable?.dispose()
        coordinator.outputDisposable = controller.output.observeValues(onOutput)

        return controller
    }

    func updateUIViewController(
        _ controller: UIViewControllerType,
        context: Context
    ) {
        let coordinator = context.coordinator

        coordinator.outputDisposable?.dispose()
        coordinator.outputDisposable = controller.output.observeValues(onOutput)

        controller.customizeEnvironment = customizeEnvironment
        controller.update(workflow: workflow)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // This coordinator allows us to manage the lifetime of the WorkflowHostingController's `output`
    // signal observation that's used to provide an `onOutput` callback to consumers.
    final class Coordinator {
        var outputDisposable: Disposable?
    }
}

private struct PreviewDemoWorkflow: Workflow {
    typealias Output = Never
    typealias Rendering = StateAccessor<State>

    @ObservableState
    struct State {
        var value: Int
    }

    func makeInitialState() -> State { .init(value: 0) }

    func render(state: State, context: RenderContext<Self>) -> Rendering {
        context.makeStateAccessor(state: state)
    }
}

private struct PreviewDemoOutputtingWorkflow: Workflow {
    typealias Output = Int
    typealias Rendering = StateAccessor<State>
    typealias State = PreviewDemoWorkflow.State

    func makeInitialState() -> State { .init(value: 0) }

    func render(state: State, context: RenderContext<Self>) -> Rendering {
        context.makeStateAccessor(state: state)
    }
}

private struct PreviewDemoScreen: ObservableScreen {
    typealias Model = StateAccessor<PreviewDemoWorkflow.State>

    var model: Model

    static func makeView(store: Store<Model>) -> some View {
        PreviewDemoView(store: store)
    }

    struct PreviewDemoView: View {
        let store: Store<Model>

        var body: some View {
            VStack {
                Text("\(store.value)")
                Button("Add", systemImage: "add") {
                    store.value += 1
                }
                Button("Reset") {
                    store.value = 0
                }
            }
        }
    }
}

struct PreviewDemoWorkflow_Preview: PreviewProvider {
    static var previews: some View {
        PreviewDemoOutputtingWorkflow()
            .mapRendering(PreviewDemoScreen.init)
            .workflowPreview(
                onOutput: { print($0) }
            )

        PreviewDemoWorkflow()
            .mapRendering(PreviewDemoScreen.init)
            .workflowPreview()
    }
}

#endif
#endif

//
//  AsyncWorkerWorkflow.swift
//  AsyncWorker
//
//  Created by Mark Johnson on 6/16/22.
//

import Workflow
import WorkflowConcurrency

// MARK: Input and Output

struct AsyncWorkerWorkflow: Workflow {
    typealias Output = Never
}

// MARK: State and Initialization

extension AsyncWorkerWorkflow {
    struct State {
        var model: Model
    }

    func makeInitialState() -> AsyncWorkerWorkflow.State {
        State(model: Model(message: "Initial State"))
    }
}

// MARK: Actions

extension AsyncWorkerWorkflow {
    enum Action: WorkflowAction {
        case fakeNetworkRequestLoaded(NetworkRequestWorker.Output)

        typealias WorkflowType = AsyncWorkerWorkflow

        func apply(toState state: inout AsyncWorkerWorkflow.State, context: ActionContext<WorkflowType.Props>) -> AsyncWorkerWorkflow.Output? {
            switch self {
            // Update state and produce an optional output based on which action was received.
            case .fakeNetworkRequestLoaded(let result):
                switch result {
                case .success(let model):
                    state.model = model
                case .failure(let error):
                    state.model = Model(message: error.localizedDescription)
                }
                return nil
            }
        }
    }
}

// MARK: Rendering

extension AsyncWorkerWorkflow {
    typealias Rendering = MessageScreen

    func render(state: AsyncWorkerWorkflow.State, context: RenderContext<AsyncWorkerWorkflow>) -> Rendering {
        NetworkRequestWorker()
            .mapOutput { result in
                Action.fakeNetworkRequestLoaded(result)
            }
            .running(in: context)

        return MessageScreen(model: state.model)
    }
}

// MARK: Workers

extension AsyncWorkerWorkflow {
    // Example worker that calls a closure based network request api.
    struct NetworkRequestWorker: Worker {
        typealias Output = Result<Model, Error>

        func run() async -> Output {
            // Create a network request
            let request = FakeNetworkManager.makeFakeNetworkRequest()
            // Create a closure to be called when the async task is cancelled.
            let onCancel = { request.cancel() }

            do {
                return try await withTaskCancellationHandler {
                    // Cancel the request.
                    onCancel()
                } operation: {
                    try await withCheckedThrowingContinuation { continuation in
                        // Perform the network request.
                        request.perform { response in
                            // Pass the result of the network request back asynchronously.
                            continuation.resume(with: .success(response))
                        }
                    }
                }
            } catch {
                return .failure(error)
            }
        }

        func isEquivalent(to otherWorker: AsyncWorkerWorkflow.NetworkRequestWorker) -> Bool {
            true
        }
    }
}

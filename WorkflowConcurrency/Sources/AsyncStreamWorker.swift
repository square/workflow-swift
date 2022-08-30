//
//  AsyncStreamWorker.swift
//  WorkflowConcurrency
//
//  Created by Mark Johnson on 5/19/22.
//

import Foundation
import Workflow

/// Workers define a unit of asynchronous work.
///
/// During a render pass, a workflow can ask the context to await the result of a worker.
///
/// When this occurs, the context checks to see if there is already a running worker of the same type.
/// If there is, and if the workers are 'equivalent', the context leaves the existing worker running.
///
/// If there is not an existing worker of this type, the context will kick off the new worker (via `run`).
@available(iOS 13.0, macOS 10.15, *)
public protocol AsyncStreamWorker: AnyWorkflowConvertible where Rendering == Void {
    /// The type of output events returned by this worker.
    associatedtype Output

    /// Returns an AsyncStream to execute the work represented by this worker.
    func run() -> AsyncStream<Output>
    /// Returns `true` if the other worker should be considered equivalent to `self`. Equivalence should take into
    /// account whatever data is meaningful to the task. For example, a worker that loads a user account from a server
    /// would not be equivalent to another worker with a different user ID.
    func isEquivalent(to otherWorker: Self) -> Bool
}

@available(iOS 13.0, macOS 10.15, *)
extension AsyncStreamWorker {
    public func asAnyWorkflow() -> AnyWorkflow<Void, Output> {
        AsyncStreamWorkerWorkflow(worker: self).asAnyWorkflow()
    }
}

@available(iOS 13.0, macOS 10.15, *)
struct AsyncStreamWorkerWorkflow<WorkerType: AsyncStreamWorker>: Workflow {
    let worker: WorkerType

    typealias Output = WorkerType.Output
    typealias Rendering = Void
    typealias State = UUID

    func makeInitialState() -> State { UUID() }

    func workflowDidChange(from previousWorkflow: AsyncStreamWorkerWorkflow<WorkerType>, state: inout UUID) {
        if !worker.isEquivalent(to: previousWorkflow.worker) {
            state = UUID()
        }
    }

    func render(state: State, context: RenderContext<AsyncStreamWorkerWorkflow>) -> Rendering {
        let sink = context.makeSink(of: AnyWorkflowAction.self)
        context.runSideEffect(key: "") { lifetime in
            let task = Task {
                for await output in worker.run() {
                    DispatchQueue.main.async {
                        sink.send(AnyWorkflowAction(sendingOutput: output))
                    }
                }
            }

            lifetime.onEnded {
                task.cancel()
            }
        }
    }
}

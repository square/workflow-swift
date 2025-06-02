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
public protocol AsyncSequenceWorker<Output>: AnyWorkflowConvertible where Rendering == Void {
    /// The type of output events returned by this worker.
    associatedtype Output

    // In iOS 18+ we can do:
    // func run() -> any AsyncSequence<Output, Never>
    // And then remove the casting in the side effect

    /// Returns an `AsyncSequence` to execute the work represented by this worker.
    func run() -> any AsyncSequence
    /// Returns `true` if the other worker should be considered equivalent to `self`. Equivalence should take into
    /// account whatever data is meaningful to the task. For example, a worker that loads a user account from a server
    /// would not be equivalent to another worker with a different user ID.
    func isEquivalent(to otherWorker: Self) -> Bool
}

extension AsyncSequenceWorker {
    public func asAnyWorkflow() -> AnyWorkflow<Void, Output> {
        AsyncSequenceWorkerWorkflow(worker: self).asAnyWorkflow()
    }
}

struct AsyncSequenceWorkerWorkflow<WorkerType: AsyncSequenceWorker>: Workflow {
    let worker: WorkerType

    typealias Output = WorkerType.Output
    typealias Rendering = Void
    typealias State = UUID

    func makeInitialState() -> State { UUID() }

    func workflowDidChange(from previousWorkflow: AsyncSequenceWorkerWorkflow<WorkerType>, state: inout UUID) {
        if !worker.isEquivalent(to: previousWorkflow.worker) {
            state = UUID()
        }
    }

    func render(state: State, context: RenderContext<AsyncSequenceWorkerWorkflow>) -> Rendering {
        let sink = context.makeSink(of: AnyWorkflowAction.self)
        context.runSideEffect(key: state) { lifetime in
            let task = Task {
                for try await output in worker.run() {
                    // Not necessary in iOS 18+ once we can use AsyncSequence<Output, Never>
                    guard let output = output as? Output else {
                        fatalError("Unexpected output type \(type(of: output)) from worker \(worker)")
                    }
                    await MainActor.run {
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

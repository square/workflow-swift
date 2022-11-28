/*
 * Copyright 2021 Square Inc.
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
public protocol Worker: AnyWorkflowConvertible where Rendering == Void {
    /// The type of output events returned by this worker.
    associatedtype Output

    /// Execute the work represented by this worker asynchronously and return the result.
    func run() async -> Output
    /// Returns `true` if the other worker should be considered equivalent to `self`. Equivalence should take into
    /// account whatever data is meaningful to the task. For example, a worker that loads a user account from a server
    /// would not be equivalent to another worker with a different user ID.
    func isEquivalent(to otherWorker: Self) -> Bool
}

@available(iOS 13.0, macOS 10.15, *)
extension Worker {
    public func asAnyWorkflow() -> AnyWorkflow<Void, Output> {
        WorkerWorkflow(worker: self).asAnyWorkflow()
    }
}

@available(iOS 13.0, macOS 10.15, *)
struct WorkerWorkflow<WorkerType: Worker>: Workflow {
    let worker: WorkerType

    typealias Output = WorkerType.Output
    typealias Rendering = Void
    typealias State = UUID

    func makeInitialState() -> State { UUID() }

    func workflowDidChange(from previousWorkflow: WorkerWorkflow<WorkerType>, state: inout UUID) {
        if !worker.isEquivalent(to: previousWorkflow.worker) {
            state = UUID()
        }
    }

    func render(state: State, context: RenderContext<WorkerWorkflow>) -> Rendering {
        let logger = WorkerLogger<WorkerType>()
        let sink = context.makeOutputSink()
        context.runSideEffect(key: "") { lifetime in
            let send: @MainActor(Output) -> Void = {
                sink.send($0)
            }
            let task = Task {
                logger.logStarted()
                let output = await worker.run()
                if Task.isCancelled {
                    logger.logFinished(status: "Cancelled")
                    logger.logFinished(status: "Finished")
                    return
                }
                logger.logOutput()
                logger.logFinished(status: "Finished")
                await send(output)
            }
            lifetime.onEnded {
                task.cancel()
            }
        }
    }
}

@available(iOS 13.0, macOS 10.15, *)
extension Worker where Self: Equatable {
    public func isEquivalent(to otherWorker: Self) -> Bool {
        self == otherWorker
    }
}

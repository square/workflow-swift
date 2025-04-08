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

#if DEBUG
import Workflow
import WorkflowTesting
import XCTest
@testable import WorkflowReactiveSwift

extension RenderTester {
    /// Mock the given worker's output, and assert that the workflow's worker `isEquivalent(to:)` the `worker`.
    ///
    /// - Parameters:
    ///   - worker: The worker that we expect was created by the workflow. Will be compared using
    ///             `isEquivalent(to:)` to assert that the workflow's worker matches.
    ///   - producingOutput: The output to be used instead of actually running the worker.
    ///                      If the workflow never tries to run the worker, then this won't be used.
    ///   - key: Key to expect this `Workflow` to be rendered with.
    @available(*, deprecated, renamed: "expectedWorker(_:mockingOutput:key:file:line:)", message: "Renamed")
    public func expect<ExpectedWorkerType: Worker>(
        worker: ExpectedWorkerType,
        producingOutput output: ExpectedWorkerType.Output? = nil,
        key: String = "",
        file: StaticString = #file, line: UInt = #line
    ) -> RenderTester<WorkflowType> {
        expectWorker(worker, mockingOutput: output, key: key, file: file, line: line)
    }

    /// Mock the given worker's output, and assert that the workflow's worker `isEquivalent(to:)` the `expectedWorker`.
    ///
    /// - Parameters:
    ///   - expectedWorker: The worker that we expect was created by the workflow. Will be compared using
    ///                     `isEquivalent(to:)` to assert that the workflow's worker matches.
    ///   - mockingOutput: The output to be used instead of actually running the worker.
    ///                    If the workflow never tries to run the worker, then this won't be used.
    ///   - key: Key to expect this `Workflow` to be rendered with.
    public func expectWorker<ExpectedWorkerType: Worker>(
        _ expectedWorker: ExpectedWorkerType,
        mockingOutput output: ExpectedWorkerType.Output? = nil,
        key: String = "",
        file: StaticString = #file, line: UInt = #line
    ) -> RenderTester<WorkflowType> {
        expectWorkflow(
            type: WorkerWorkflow<ExpectedWorkerType>.self,
            key: key,
            producingRendering: (),
            producingOutput: output,
            assertions: { workflow in
                guard !workflow.worker.isEquivalent(to: expectedWorker) else {
                    return
                }
                XCTFail(
                    "Workers of type \(ExpectedWorkerType.self) not equivalent. Expected: \(expectedWorker). Got: \(workflow.worker)",
                    file: file,
                    line: line
                )
            }
        )
    }
}
#endif

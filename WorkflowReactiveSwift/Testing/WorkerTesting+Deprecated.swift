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
    import Foundation
    import WorkflowTesting
    import XCTest
    @testable import WorkflowReactiveSwift

    @available(*, deprecated, message: "See `RenderTester` documentation for new style.")
    public struct ExpectedWorker {
        let worker: Any
        let expectedWorkflow: ExpectedWorkflow

        private let output: Any?

        public init<WorkerType: Worker>(
            worker: WorkerType,
            output: WorkerType.Output? = nil,
            file: StaticString = #file, line: UInt = #line
        ) {
            self.worker = worker
            self.output = output

            self.expectedWorkflow = ExpectedWorkflow(
                type: WorkerWorkflow<WorkerType>.self,
                key: "",
                rendering: (),
                output: output
            ) { workflow in
                guard !workflow.worker.isEquivalent(to: worker) else {
                    return
                }
                XCTFail(
                    "Expected worker of type: \(WorkerType.self) not equivalent",
                    file: file,
                    line: line
                )
            }
        }

        func isEquivalent<WorkerType: Worker>(to actual: WorkerType) -> Bool {
            guard let expectedWorker = worker as? WorkerType else {
                return false
            }

            return expectedWorker.isEquivalent(to: actual)
        }
    }

    @available(*, deprecated, message: "See `RenderTester` documentation for new style.")
    public extension RenderExpectations {
        init(
            expectedState: ExpectedState<WorkflowType>? = nil,
            expectedOutput: ExpectedOutput<WorkflowType>? = nil,
            expectedWorkers: [ExpectedWorker] = [],
            expectedWorkflows: [ExpectedWorkflow] = [],
            expectedSideEffects: [ExpectedSideEffect<WorkflowType>] = []
        ) {
            self.init(
                expectedState: expectedState,
                expectedOutput: expectedOutput,
                expectedWorkflows: expectedWorkflows + expectedWorkers.map { $0.expectedWorkflow },
                expectedSideEffects: expectedSideEffects
            )
        }
    }

    public extension RenderTester {
        @discardableResult
        @available(*, deprecated, message: "See `RenderTester` documentation for new style.")
        func render(
            file: StaticString = #file, line: UInt = #line,
            expectedState: ExpectedState<WorkflowType>? = nil,
            expectedOutput: ExpectedOutput<WorkflowType>? = nil,
            expectedWorkers: [ExpectedWorker] = [],
            expectedWorkflows: [ExpectedWorkflow] = [],
            expectedSideEffects: [ExpectedSideEffect<WorkflowType>] = [],
            assertions: (WorkflowType.Rendering) -> Void = { _ in }
        ) -> RenderTester<WorkflowType> {
            let expectations = RenderExpectations(
                expectedState: expectedState,
                expectedOutput: expectedOutput,
                expectedWorkers: expectedWorkers,
                expectedWorkflows: expectedWorkflows,
                expectedSideEffects: expectedSideEffects
            )

            return render(file: file, line: line, with: expectations, assertions: assertions)
        }
    }
#endif

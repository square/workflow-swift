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
    import XCTest

    /// A set of expectations for use with the `WorkflowRenderTester`. All of the expectations must be fulfilled
    /// for a `render` test to pass.
    @available(*, deprecated, message: "See `RenderTester` documentation for new style.")
    public struct RenderExpectations<WorkflowType: Workflow> {
        var expectedState: ExpectedState<WorkflowType>?
        var expectedOutput: ExpectedOutput<WorkflowType>?
        var expectedWorkers: [ExpectedWorker]
        var expectedWorkflows: [ExpectedWorkflow]
        var expectedSideEffects: [AnyHashable: ExpectedSideEffect<WorkflowType>]

        public init(
            expectedState: ExpectedState<WorkflowType>? = nil,
            expectedOutput: ExpectedOutput<WorkflowType>? = nil,
            expectedWorkers: [ExpectedWorker] = [],
            expectedWorkflows: [ExpectedWorkflow] = [],
            expectedSideEffects: [ExpectedSideEffect<WorkflowType>] = []
        ) {
            self.expectedState = expectedState
            self.expectedOutput = expectedOutput
            self.expectedWorkers = expectedWorkers
            self.expectedWorkflows = expectedWorkflows
            self.expectedSideEffects = expectedSideEffects.reduce(into: [AnyHashable: ExpectedSideEffect<WorkflowType>]()) { res, expectedSideEffect in
                res[expectedSideEffect.storage.key] = expectedSideEffect
            }
        }
    }

    @available(*, deprecated, message: "See `RenderTester` documentation for new style.")
    public struct ExpectedOutput<WorkflowType: Workflow> {
        let output: WorkflowType.Output
        let isEquivalent: (WorkflowType.Output, WorkflowType.Output) -> Bool

        public init<Output>(output: Output, isEquivalent: @escaping (Output, Output) -> Bool) where Output == WorkflowType.Output {
            self.output = output
            self.isEquivalent = isEquivalent
        }

        public init<Output>(output: Output) where Output == WorkflowType.Output, Output: Equatable {
            self.init(output: output, isEquivalent: { expected, actual in
                expected == actual
            })
        }

        func verify(in result: RenderTesterResult<WorkflowType>, file: StaticString, line: UInt) {
            result.verifyOutput {
                XCTAssert(isEquivalent(output, $0), "Output \($0) is not equal to expected \(output)", file: file, line: line)
            }
        }
    }

    @available(*, deprecated, message: "See `RenderTester` documentation for new style.")
    public struct ExpectedState<WorkflowType: Workflow> {
        let state: WorkflowType.State
        let isEquivalent: (WorkflowType.State, WorkflowType.State) -> Bool

        /// Create a new expected state from a state with an equivalence block. `isEquivalent` will be
        /// called to validate that the expected state matches the actual state after a render pass.
        public init<State>(state: State, isEquivalent: @escaping (State, State) -> Bool) where State == WorkflowType.State {
            self.state = state
            self.isEquivalent = isEquivalent
        }

        public init<State>(state: State) where WorkflowType.State == State, State: Equatable {
            self.init(state: state, isEquivalent: { expected, actual in
                expected == actual
            })
        }

        func verify(in result: RenderTesterResult<WorkflowType>, file: StaticString, line: UInt) {
            result.verifyState {
                XCTAssert(isEquivalent(state, $0), "State \($0) is not equal to expected \(state)", file: file, line: line)
            }
        }
    }

    @available(*, deprecated, message: "See `RenderTester` documentation for new style.")
    public struct ExpectedWorker {
        fileprivate class AnyStorage {
            func expect<WorkflowType: Workflow>(in tester: RenderTester<WorkflowType>) {
                fatalError()
            }
        }

        private final class Storage<WorkerType: Worker>: AnyStorage {
            let worker: WorkerType
            let output: WorkerType.Output?

            init(worker: WorkerType, output: WorkerType.Output?) {
                self.worker = worker
                self.output = output
            }

            override func expect<WorkflowType: Workflow>(in tester: RenderTester<WorkflowType>) {
                _ = tester.expect(worker: worker, producingOutput: output)
            }
        }

        fileprivate let storage: AnyStorage

        /// Create a new expected worker with an optional output. If `output` is not nil, it will be emitted
        /// when this worker is declared in the render pass.
        public init<WorkerType: Worker>(worker: WorkerType, output: WorkerType.Output? = nil) {
            self.storage = Storage(worker: worker, output: output)
        }

        func expect<ParentWorkflowType: Workflow>(in tester: RenderTester<ParentWorkflowType>) {
            storage.expect(in: tester)
        }
    }

    @available(*, deprecated, message: "See `RenderTester` documentation for new style.")
    public struct ExpectedSideEffect<WorkflowType: Workflow> {
        fileprivate class Storage {
            let key: AnyHashable

            init(key: AnyHashable) {
                self.key = key
            }

            func expect(in tester: RenderTester<WorkflowType>) {
                _ = tester.expectSideEffect(key: key)
            }
        }

        private final class StorageWithAction<ActionType: WorkflowAction>: Storage where ActionType.WorkflowType == WorkflowType {
            let action: ActionType

            init(key: AnyHashable, action: ActionType) {
                self.action = action
                super.init(key: key)
            }

            override func expect(in tester: RenderTester<WorkflowType>) {
                _ = tester.expectSideEffect(key: key, producingAction: action)
            }
        }

        fileprivate let storage: Storage

        public init(key: AnyHashable) {
            self.storage = Storage(key: key)
        }

        public init<ActionType: WorkflowAction>(key: AnyHashable, action: ActionType) where ActionType.WorkflowType == WorkflowType {
            self.storage = StorageWithAction(key: key, action: action)
        }

        func expect(in tester: RenderTester<WorkflowType>) {
            storage.expect(in: tester)
        }
    }

    @available(*, deprecated, message: "See `RenderTester` documentation for new style.")
    public struct ExpectedWorkflow {
        fileprivate class AnyStorage {
            func expect<ParentWorkflowType: Workflow>(in tester: RenderTester<ParentWorkflowType>) {
                fatalError()
            }
        }

        private final class Storage<ExpectedWorkflowType: Workflow>: AnyStorage {
            let key: String
            let rendering: ExpectedWorkflowType.Rendering
            let output: ExpectedWorkflowType.Output?

            init(key: String, rendering: ExpectedWorkflowType.Rendering, output: ExpectedWorkflowType.Output?) {
                self.key = key
                self.rendering = rendering
                self.output = output
            }

            override func expect<WorkflowType: Workflow>(in tester: RenderTester<WorkflowType>) {
                _ = tester.expectWorkflow(type: ExpectedWorkflowType.self, key: key, producingRendering: rendering, producingOutput: output)
            }
        }

        fileprivate let storage: AnyStorage

        public init<WorkflowType: Workflow>(type: WorkflowType.Type, key: String = "", rendering: WorkflowType.Rendering, output: WorkflowType.Output? = nil) {
            self.storage = Storage<WorkflowType>(key: key, rendering: rendering, output: output)
        }

        func expect<ParentWorkflowType: Workflow>(in tester: RenderTester<ParentWorkflowType>) {
            storage.expect(in: tester)
        }
    }

#endif

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
        var expectedWorkflows: [ExpectedWorkflow]
        var expectedSideEffects: [AnyHashable: ExpectedSideEffect<WorkflowType>]

        public init(
            expectedState: ExpectedState<WorkflowType>? = nil,
            expectedOutput: ExpectedOutput<WorkflowType>? = nil,
            expectedWorkflows: [ExpectedWorkflow] = [],
            expectedSideEffects: [ExpectedSideEffect<WorkflowType>] = []
        ) {
            self.expectedState = expectedState
            self.expectedOutput = expectedOutput
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
            result.verifyOutput(file: file, line: line) {
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
            result.verifyState(file: file, line: line) {
                XCTAssert(isEquivalent(state, $0), "State \($0) is not equal to expected \(state)", file: file, line: line)
            }
        }
    }

    public struct ExpectedSideEffect<WorkflowType: Workflow> {
        fileprivate class Storage {
            let key: AnyHashable

            init(key: AnyHashable) {
                self.key = key
            }

            func expect(in tester: inout RenderTester<WorkflowType>, file: StaticString, line: UInt) {
                tester = tester.expectSideEffect(key: key, file: file, line: line)
            }
        }

        private final class StorageWithAction<ActionType: WorkflowAction>: Storage where ActionType.WorkflowType == WorkflowType {
            let action: ActionType

            init(key: AnyHashable, action: ActionType) {
                self.action = action
                super.init(key: key)
            }

            override func expect(in tester: inout RenderTester<WorkflowType>, file: StaticString, line: UInt) {
                tester = tester.expectSideEffect(key: key, producingAction: action, file: file, line: line)
            }
        }

        fileprivate let storage: Storage

        public init(key: AnyHashable) {
            self.storage = Storage(key: key)
        }

        public init<ActionType: WorkflowAction>(key: AnyHashable, action: ActionType) where ActionType.WorkflowType == WorkflowType {
            self.storage = StorageWithAction(key: key, action: action)
        }

        func expect(in tester: inout RenderTester<WorkflowType>, file: StaticString, line: UInt) {
            storage.expect(in: &tester, file: file, line: line)
        }
    }

    @available(*, deprecated, message: "See `RenderTester` documentation for new style.")
    public struct ExpectedWorkflow {
        fileprivate class AnyStorage {
            func expect<ParentWorkflowType: Workflow>(in tester: inout RenderTester<ParentWorkflowType>, file: StaticString, line: UInt) {
                fatalError()
            }
        }

        private final class Storage<ExpectedWorkflowType: Workflow>: AnyStorage {
            let key: String
            let rendering: ExpectedWorkflowType.Rendering
            let output: ExpectedWorkflowType.Output?
            let assertions: (ExpectedWorkflowType) -> Void

            init(key: String, rendering: ExpectedWorkflowType.Rendering, output: ExpectedWorkflowType.Output?, assertions: @escaping (ExpectedWorkflowType) -> Void) {
                self.key = key
                self.rendering = rendering
                self.output = output
                self.assertions = assertions
            }

            override func expect<WorkflowType: Workflow>(in tester: inout RenderTester<WorkflowType>, file: StaticString, line: UInt) {
                tester = tester.expectWorkflow(type: ExpectedWorkflowType.self, key: key, producingRendering: rendering, producingOutput: output, file: file, line: line)
            }
        }

        fileprivate let storage: AnyStorage

        public init<WorkflowType: Workflow>(type: WorkflowType.Type, key: String = "", rendering: WorkflowType.Rendering, output: WorkflowType.Output? = nil, assertions: @escaping (WorkflowType) -> Void = { _ in }) {
            self.storage = Storage<WorkflowType>(key: key, rendering: rendering, output: output, assertions: assertions)
        }

        func expect<ParentWorkflowType: Workflow>(in tester: inout RenderTester<ParentWorkflowType>, file: StaticString, line: UInt) {
            storage.expect(in: &tester, file: file, line: line)
        }
    }

#endif

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

// WorkflowTesting only available in Debug mode.
//
// `@testable import Workflow` will fail compilation in Release mode.
#if DEBUG

    import XCTest
    @testable import Workflow

    extension Workflow {
        /// Returns a `RenderTester` with a specified initial state.
        public func renderTester(initialState: Self.State) -> RenderTester<Self> {
            return RenderTester(workflow: self, state: initialState)
        }

        /// Returns a `RenderTester` with an initial state provided by `self.makeInitialState()`
        public func renderTester() -> RenderTester<Self> {
            return renderTester(initialState: makeInitialState())
        }
    }

    /// Testing helper for validating the behavior of calls to `render`.
    ///
    /// Usage: `expect` workflows and side effects then validate with a call to `render` and
    /// the resulting `RenderTesterResult`.
    /// Side-effects may be performed against the rendering to validate the behavior of actions.
    ///
    /// To directly test actions and their effects, use the `WorkflowActionTester`.
    ///
    /// ```
    /// workflow
    ///     .renderTester(initialState: TestWorkflow.State())
    ///     .expect(
    ///         worker: TestWorker(),
    ///         producingOutput: TestWorker.Output.success
    ///     )
    ///     .expectWorkflow(
    ///         type: ChildWorkflow.self,
    ///         key: "key",
    ///         rendering: "rendering",
    ///         producingOutput: ChildWorkflow.Output.success
    ///     )
    ///     .render { rendering in
    ///         XCTAssertEqual("expected text on rendering", rendering.text)
    ///     }
    ///     .assert(state: TestWorkflow.State())
    ///     .assert(output: TestWorkflow.Output.finished)
    /// ```
    ///
    /// Validating the rendering only from the initial state provided by the workflow:
    /// ```
    /// workflow
    ///     .renderTester()
    ///     .render { rendering in
    ///         XCTAssertEqual("expected text on rendering", rendering.text)
    ///     }
    /// ```
    ///
    /// Validate the state was updated from a callback on the rendering:
    /// ```
    /// workflow
    ///     .renderTester()
    ///     .render { rendering in
    ///         XCTAssertEqual("expected text on rendering", rendering.text)
    ///         rendering.updateText("updated")
    ///     }
    ///     .assert(
    ///         state: TestWorkflow.State(text: "updated")
    ///     )
    /// ```
    ///
    /// Validate an output was received from the workflow. The `action()` on the rendering will cause an action that will return an output.
    /// ```
    /// workflow
    ///     .renderTester()
    ///     .render { rendering in
    ///         rendering.action()
    ///     }
    ///     .assert(
    ///        output: .success
    ///     )
    /// ```
    ///
    /// Validate a worker is running, and simulate the effect of its output:
    /// ```
    /// workflow
    ///     .renderTester(initialState: TestWorkflow.State(loadingState: .loading))
    ///     .expect(
    ///         worker: TestWorker(),
    ///         output: TestWorker.Output.success
    ///     )
    ///     .render { _ in }
    /// ```
    ///
    /// Validate a child workflow is run, and simulate the effect of its output:
    /// ```
    /// workflow
    ///     .renderTester(initialState: TestWorkflow.State(loadingState: .loading))
    ///     .expectWorkflow(
    ///         type: ChildWorkflow.self,
    ///         rendering: "rendering",
    ///         producingOutput: ChildWorkflow.Output.success
    ///     )
    ///     .render { _ in }
    /// ```
    public struct RenderTester<WorkflowType: Workflow> {
        let workflow: WorkflowType
        let state: WorkflowType.State

        private let expectedWorkflows: [AnyExpectedWorkflow]
        private let expectedSideEffects: [AnyHashable: ExpectedSideEffect<WorkflowType>]

        init(
            workflow: WorkflowType,
            state: WorkflowType.State,
            expectedWorkflows: [AnyExpectedWorkflow] = [],
            expectedSideEffects: [AnyHashable: ExpectedSideEffect<WorkflowType>] = [:]
        ) {
            self.workflow = workflow
            self.state = state
            self.expectedWorkflows = expectedWorkflows
            self.expectedSideEffects = expectedSideEffects
        }

        /// Expect the given workflow type in the next rendering.
        ///
        /// - Parameters:
        ///   - type: The type of the expected workflow.
        ///   - key: The key of the expected workflow (if specified).
        ///   - rendering: The rendering result that should be returned when the workflow of this type is rendered.
        ///   - output: An output that should be returned after the workflow of this type is rendered, if any.
        ///   - assertions: Additional assertions for the given workflow, if any. You may use this to assert the properties of the requested workflow are as expected.
        public func expectWorkflow<ExpectedWorkflowType: Workflow>(
            type: ExpectedWorkflowType.Type,
            key: String = "",
            producingRendering rendering: ExpectedWorkflowType.Rendering,
            producingOutput output: ExpectedWorkflowType.Output? = nil,
            file: StaticString = #file, line: UInt = #line,
            assertions: @escaping (ExpectedWorkflowType) -> Void = { _ in }
        ) -> RenderTester<WorkflowType> {
            return RenderTester(
                workflow: workflow,
                state: state,
                expectedWorkflows: expectedWorkflows.appending(
                    ExpectedWorkflow<ExpectedWorkflowType>(
                        key: key,
                        rendering: rendering,
                        output: output,
                        assertions: assertions,
                        file: file,
                        line: line
                    )
                ),
                expectedSideEffects: expectedSideEffects
            )
        }

        /// Expect a side-effect for the given key.
        ///
        /// - Parameter key: The key to expect.
        public func expectSideEffect(
            key: AnyHashable,
            file: StaticString = #file, line: UInt = #line
        ) -> RenderTester<WorkflowType> {
            return RenderTester(
                workflow: workflow,
                state: state,
                expectedWorkflows: expectedWorkflows,
                expectedSideEffects: expectedSideEffects.setting(
                    key: key,
                    value: ExpectedSideEffect(
                        key: key,
                        file: file,
                        line: line
                    )
                )
            )
        }

        /// Expect a side-effect for the given key, and produce the given action when it is requested.
        ///
        /// - Parameters:
        ///   - key: The key to expect.
        ///   - action: The action to produce when this side-effect is requested.
        public func expectSideEffect<ActionType>(
            key: AnyHashable,
            producingAction action: ActionType,
            file: StaticString = #file, line: UInt = #line
        ) -> RenderTester<WorkflowType> where ActionType: WorkflowAction, ActionType.WorkflowType == WorkflowType {
            return RenderTester(
                workflow: workflow,
                state: state,
                expectedWorkflows: expectedWorkflows,
                expectedSideEffects: expectedSideEffects.setting(
                    key: key,
                    value: ExpectedSideEffectWithAction(
                        key: key,
                        action: action,
                        file: file,
                        line: line
                    )
                )
            )
        }

        /// Render the workflow under test. At this point, you should have set up all expectations.
        ///
        /// The given `assertions` closure will be called with the produced rendering, allowing you to assert its properties or
        /// perform actions on it (such as closures that are wired up to a `Sink` inside the workflow.
        ///
        /// - Parameters:
        ///   - assertions: A closure called with the produced rendering for verification
        /// - Returns: A `RenderTesterResult` that can be used to verify expected resulting state or outputs.
        @discardableResult
        public func render(
            file: StaticString = #file, line: UInt = #line,
            assertions: (WorkflowType.Rendering) throws -> Void
        ) rethrows -> RenderTesterResult<WorkflowType> {
            let contextImplementation = TestContext(
                state: state,
                expectedWorkflows: expectedWorkflows,
                expectedSideEffects: expectedSideEffects,
                file: file,
                line: line
            )
            let context = RenderContext.make(implementation: contextImplementation)
            let rendering = workflow.render(state: contextImplementation.state, context: context)

            contextImplementation.assertNoLeftOverExpectations()

            try assertions(rendering)

            return RenderTesterResult<WorkflowType>(
                state: contextImplementation.state,
                appliedAction: contextImplementation.appliedAction,
                output: contextImplementation.producedOutput
            )
        }
    }

    extension Collection {
        fileprivate func appending(_ element: Element) -> [Element] {
            return self + [element]
        }
    }

    extension Dictionary {
        fileprivate func setting(key: Key, value: Value) -> [Key: Value] {
            var newDictionary = self
            newDictionary[key] = value
            return newDictionary
        }
    }

#endif

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

    import XCTest
    @testable import Workflow

    extension RenderTester {
        internal final class TestContext: RenderContextType {
            var state: WorkflowType.State
            var expectedWorkflows: [AnyExpectedWorkflow]
            var expectedSideEffects: [AnyHashable: ExpectedSideEffect<WorkflowType>]
            var appliedAction: AppliedAction<WorkflowType>?
            var producedOutput: WorkflowType.Output?
            let file: StaticString
            let line: UInt

            internal init(
                state: WorkflowType.State,
                expectedWorkflows: [AnyExpectedWorkflow],
                expectedSideEffects: [AnyHashable: ExpectedSideEffect<WorkflowType>],
                file: StaticString,
                line: UInt
            ) {
                self.state = state
                self.expectedWorkflows = expectedWorkflows
                self.expectedSideEffects = expectedSideEffects
                self.file = file
                self.line = line
            }

            func render<Child, Action>(workflow: Child, key: String, outputMap: @escaping (Child.Output) -> Action) -> Child.Rendering where Child: Workflow, Action: WorkflowAction, Action.WorkflowType == WorkflowType {
                let matchingTypes = expectedWorkflows.compactMap { $0 as? ExpectedWorkflow<Child> }
                guard let expectedWorkflow = matchingTypes.first(where: { $0.key == key }) else {
                    let sameTypeDifferentKeys = matchingTypes.map { $0.key }
                    let sameKeyDifferentTypes = expectedWorkflows.filter { $0.key == key }.map { $0.workflowType }

                    let diagnosticMessage: String

                    if sameTypeDifferentKeys.count == 1 {
                        diagnosticMessage = "Expecting key \"\(sameTypeDifferentKeys[0])\"."
                    } else if sameTypeDifferentKeys.count > 1 {
                        diagnosticMessage = "Expecting key in \"\(sameTypeDifferentKeys)\"."
                    } else if sameKeyDifferentTypes.count == 1 {
                        diagnosticMessage = "Found expecation of type \(sameKeyDifferentTypes[0]) for key \"\(key)\"."
                    } else if sameKeyDifferentTypes.count > 1 {
                        diagnosticMessage = "Found expecations for types \(sameKeyDifferentTypes) with key \"\(key)\"."
                    } else {
                        diagnosticMessage = ""
                    }
                    XCTFail("Unexpected workflow of type \(Child.self) with key \"\(key)\". \(diagnosticMessage)", file: file, line: line)

                    // We can “recover” from missing Void-rendering workflows since there’s only one possible value to return
                    if Child.Rendering.self == Void.self {
                        // Couldn’t find a nicer way to do this polymorphically
                        return () as! Child.Rendering
                    }
                    fatalError("Unable to continue.")
                }

                expectedWorkflows.removeAll(where: { $0 === expectedWorkflow })

                if let output = expectedWorkflow.output {
                    apply(action: outputMap(output))
                }
                expectedWorkflow.assertions(workflow)
                return expectedWorkflow.rendering
            }

            func makeSink<ActionType>(of actionType: ActionType.Type) -> Sink<ActionType> where ActionType: WorkflowAction, ActionType.WorkflowType == WorkflowType {
                return Sink<ActionType> { action in
                    self.apply(action: action)
                }
            }

            func runSideEffect(key: AnyHashable, action: (Lifetime) -> Void) {
                guard let sideEffect = expectedSideEffects.removeValue(forKey: key) else {
                    XCTFail("Unexpected side-effect with key \"\(key)\"", file: file, line: line)
                    return
                }

                sideEffect.apply(context: self)
            }

            /// Validate the expectations were fulfilled, or fail if not.
            func assertNoLeftOverExpectations() {
                for expectedWorkflow in expectedWorkflows {
                    XCTFail("Expected child workflow of type: \(expectedWorkflow.workflowType), key: \"\(expectedWorkflow.key)\"", file: file, line: expectedWorkflow.line)
                }

                for (key, expectedSideEffect) in expectedSideEffects {
                    XCTFail("Expected side-effect with key: \"\(key)\"", file: expectedSideEffect.file, line: expectedSideEffect.line)
                }
            }

            private func apply<ActionType>(action: ActionType) where ActionType: WorkflowAction, ActionType.WorkflowType == WorkflowType {
                XCTAssertNil(appliedAction, "Received multiple actions in a single render test", file: file, line: line)
                appliedAction = AppliedAction(action)
                let output = action.apply(toState: &state)

                if let output = output {
                    XCTAssertNil(producedOutput, "Received multiple outputs in a single render test", file: file, line: line)
                    producedOutput = output
                }
            }
        }
    }

#endif

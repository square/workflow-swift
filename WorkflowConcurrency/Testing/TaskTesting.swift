/*
 * Copyright 2022 Square Inc.
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

    import Combine
    import Workflow
    import WorkflowTesting
    import XCTest
    @testable import WorkflowConcurrency

    @available(macOS 10.15, *)
    @available(iOS 13.0, *)
    extension RenderTester {
        /// Expect a `Task`s.
        ///
        /// `TaskWorkflow` is used to execute to `Task`s.
        ///
        /// - Parameters:
        ///   - producingOutput: An output that should be returned when this worker is requested, if any.
        ///   - key: Key to expect this `Workflow` to be rendered with.
        public func expect<Value>(
            task: Task<Value, Never>.Type,
            output: Value,
            key: String = ""
        ) -> RenderTester<WorkflowType> {
            expectWorkflow(
                type: TaskWorkflow<Value>.self,
                key: key,
                producingRendering: (),
                producingOutput: output,
                assertions: { _ in }
            )
        }
    }

#endif

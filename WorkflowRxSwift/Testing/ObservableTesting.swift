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
@testable import WorkflowRxSwift

public extension RenderTester {
    /// Expect the given worker. It will be checked for `isEquivalent(to:)` with the requested worker.

    /// - Parameters:
    ///   - outputType: The `OutputType` of the expected `ObservableWorkflow`.
    ///   - producingOutput: An output that will be returned when this worker is requested, if any.
    ///   - key: Key to expect this `Workflow` to be rendered with.
    func expectObservable<OutputType>(
        outputType: OutputType.Type = OutputType.self,
        producingOutput output: OutputType? = nil,
        key: String = "",
        file: StaticString = #file, line: UInt = #line
    ) -> RenderTester<WorkflowType> {
        expectWorkflow(
            type: ObservableWorkflow<OutputType>.self,
            key: key,
            producingRendering: (),
            producingOutput: output,
            assertions: { _ in }
        )
    }
}
#endif

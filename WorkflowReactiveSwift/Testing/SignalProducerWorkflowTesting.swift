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

public extension RenderTester {
    /// Expect a `SignalProducer` with an optional output.
    ///
    /// `SignalProducerWorkflow` is used to subscribe to `SignalProducer`s and `Signal`s.
    ///
    ///  ⚠️ N.B. If you are testing a case in which multiple `SignalProducerWorkflow`s are expected, **only one of them** may have a non-nil `producingOutput` parameter.
    ///
    /// - Parameters:
    ///   - outputType: The `OutputType` of the expected `SignalProducerWorkflow`. Typically this will be correctly inferred by the type system, but may need to be explicitly specified if particular optionality is desired.
    ///   - producingOutput: An output that will be returned when this worker is requested, if any.
    ///   - key: Key to expect this `Workflow` to be rendered with.
    func expectSignalProducer<OutputType>(
        outputType: OutputType.Type = OutputType.self,
        producingOutput: OutputType? = nil,
        key: String = "",
        file: StaticString = #file, line: UInt = #line
    ) -> RenderTester<WorkflowType> {
        expectWorkflow(
            type: SignalProducerWorkflow<OutputType>.self,
            key: key,
            producingRendering: (),
            producingOutput: producingOutput,
            assertions: { _ in }
        )
    }
}
#endif

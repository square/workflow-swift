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

#if DEBUG

import Combine
import Workflow
import WorkflowTesting
import XCTest
@testable import WorkflowCombine

public extension RenderTester {
    /// Expect a `Publisher`-based Workflow.
    ///
    /// `PublisherWorkflow` is used to subscribe to `Publisher`s.
    ///
    /// - Parameters:
    ///   - publisher: Type of the Publisher-based Workflow to expect
    ///   - producingOutput: An output that will be returned when this worker is requested, if any.
    ///   - key: Key to expect this `Workflow` to be rendered with.
    func expect<PublisherType: Publisher>(
        publisher: PublisherType.Type,
        producingOutput output: PublisherType.Output? = nil,
        key: String = ""
    ) -> RenderTester<WorkflowType> where PublisherType.Failure == Never {
        expectWorkflow(
            type: PublisherWorkflow<PublisherType>.self,
            key: key,
            producingRendering: (),
            producingOutput: output,
            assertions: { _ in }
        )
    }

    @available(*, deprecated, renamed: "expect(publisher:producingOutput:key:)")
    func expect<PublisherType: Publisher>(
        publisher: PublisherType.Type,
        output: PublisherType.Output,
        key: String = ""
    ) -> RenderTester<WorkflowType> where PublisherType.Failure == Never {
        expect(
            publisher: publisher,
            producingOutput: output,
            key: key
        )
    }
}

#endif

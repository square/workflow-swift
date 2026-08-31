/*
 * Copyright 2026 Square Inc.
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

import XCTest
@testable import Workflow

@MainActor
final class WorkflowHostAsyncTests: XCTestCase {
    func test_renderings_conflatesToNewestForSlowConsumer() async {
        let host = WorkflowHost(workflow: EchoWorkflow(value: 1))
        let renderings = host.renderings

        // No consumer is iterating yet; .bufferingNewest(1) keeps only the
        // most recent value (updates overwrite the buffered initial value).
        host.update(workflow: EchoWorkflow(value: 2))
        host.update(workflow: EchoWorkflow(value: 3))

        var iterator = renderings.makeAsyncIterator()
        let first = await iterator.next()
        XCTAssertEqual(first, 3)
    }

    func test_renderings_currentValueFirst_whenConsumedBeforeUpdates() async {
        let host = WorkflowHost(workflow: EchoWorkflow(value: 1))
        var iterator = host.renderings.makeAsyncIterator()

        let first = await iterator.next()
        XCTAssertEqual(first, 1)
    }

    func test_outputs_deliversEveryOutputInOrder_noDrops() async {
        let host = WorkflowHost(workflow: OutputEmittingWorkflow())
        let outputs = host.outputs
        let sink = host.rendering // Rendering is the event-sending closure

        // Emit a burst BEFORE consuming: a .values-style bridge would drop
        // these; the buffered stream must not.
        for i in 0 ..< 100 {
            sink(i)
        }

        var received: [Int] = []
        var iterator = outputs.makeAsyncIterator()
        for _ in 0 ..< 100 {
            if let value = await iterator.next() {
                received.append(value)
            }
        }

        XCTAssertEqual(received, Array(0 ..< 100))
    }

    func test_streams_finishWhenHostIsDeallocated() async {
        var host: WorkflowHost<EchoWorkflow>? = WorkflowHost(workflow: EchoWorkflow(value: 1))
        let renderings = host!.renderings
        host = nil

        var received: [Int] = []
        for await value in renderings {
            received.append(value)
        }
        // Initial value was buffered; then the stream finished.
        XCTAssertEqual(received, [1])
    }

    // MARK: - Fixtures

    fileprivate struct EchoWorkflow: Workflow {
        var value: Int
        typealias State = Void
        typealias Rendering = Int
        func render(state: State, context: RenderContext<EchoWorkflow>) -> Int { value }
    }

    /// Renders a closure that emits its argument as an Output.
    fileprivate struct OutputEmittingWorkflow: Workflow {
        typealias State = Void
        typealias Output = Int
        typealias Rendering = (Int) -> Void

        func render(state: State, context: RenderContext<OutputEmittingWorkflow>) -> Rendering {
            let sink = context.makeOutputSink()
            return { sink.send($0) }
        }
    }
}

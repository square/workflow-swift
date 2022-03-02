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

import Workflow
import XCTest
@testable import WorkflowConcurrency

@available(iOS 15.2, macOS 11.3, *)
class WorkerTests: XCTestCase {
    func testWorkerOutput() {
        let host = WorkflowHost(
            workflow: TaskTestWorkflow(key: "")
        )

        let expectation = XCTestExpectation()
        let disposable = host.rendering.signal.observeValues { rendering in
            expectation.fulfill()
        }

        XCTAssertEqual(0, host.rendering.value)

        wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(1, host.rendering.value)

        disposable?.dispose()
    }
}

@available(iOS 15.2, macOS 11.3, *)
private struct TaskTestWorkflow: Workflow {
    typealias State = Int
    typealias Rendering = Int

    let key: String

    func makeInitialState() -> Int { 0 }

    func render(state: Int, context: RenderContext<TaskTestWorkflow>) -> Int {
        TaskTestWorker()
            .mapOutput { output in
                AnyWorkflowAction { state in
                    state = output
                    return nil
                }
            }
            .running(in: context, key: key)
        return state
    }
}

@available(iOS 15.2, macOS 11.3, *)
private struct TaskTestWorker: Worker {
    typealias Output = Int

    func run() async -> Int {
        do {
            try await Task.sleep(nanoseconds: 3000000000)
        } catch {}

        return 1
    }

    func isEquivalent(to otherWorker: TaskTestWorker) -> Bool { true }
}

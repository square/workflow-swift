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

import Combine
import Foundation
import Workflow
import XCTest
@testable import WorkflowConcurrency

@available(iOS 13.0, macOS 10.15, *)
class PublisherTests: XCTestCase {
    func test_output() {
        let host = WorkflowHost(
            workflow: TaskWorkflow(task:
                Task { "hello world" }
            )
        )

        let expectation = XCTestExpectation()
        var outputValue: String?
        let disposable = host.output.signal.observeValues { output in
            outputValue = output
            print(output)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual("hello world", outputValue)

        disposable?.dispose()
    }
}

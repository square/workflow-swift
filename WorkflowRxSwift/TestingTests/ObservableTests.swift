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

import Foundation
import RxSwift
import Workflow
import WorkflowRxSwiftTesting
import XCTest

class ObservableTests: XCTestCase {
    func testObservableWorkflow() {
        TestWorkflow()
            .renderTester()
            .expectObservable(producingOutput: 1, key: "123")
            .render {}
    }

    func test_observableWorkflow_optionalOutputType() {
        OptionalOutputWorkflow()
            .renderTester()
            .expectObservable(
                outputType: Int?.self, // comment this out & test fails
                producingOutput: nil as Int?,
                key: "123"
            )
            .render {}
    }

    private struct TestWorkflow: Workflow {
        typealias State = Void
        typealias Rendering = Void

        func render(state: State, context: RenderContext<Self>) -> Rendering {
            Observable.from([1])
                .mapOutput { _ in AnyWorkflowAction<TestWorkflow>.noAction }
                .running(in: context, key: "123")
        }
    }

    private struct OptionalOutputWorkflow: Workflow {
        typealias State = Void
        typealias Rendering = Void
        typealias Output = Int?

        func render(state: State, context: RenderContext<Self>) -> Rendering {
            Observable.from([1])
                .map { Int?.some($0) }
                .mapOutput { _ in AnyWorkflowAction<Self>.noAction }
                .rendered(in: context, key: "123")
        }
    }
}

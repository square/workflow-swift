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
import ReactiveSwift
import Workflow
import WorkflowReactiveSwiftTesting
import XCTest
@testable import WorkflowReactiveSwift

@available(*, deprecated)
class SignalWorkerTests: XCTestCase {
    func test_singleSignalWorker() {
        let (signal, _) = Signal<AnyWorkflowAction<MultipleSignalWorkersWorkflow>, Never>.pipe()
        MultipleSignalWorkersWorkflow(numberOfSignalWorkers: 1)
            .renderTester()
            .expect(worker: SignalWorker(key: 0, signal: signal))
            .render { _ in }
    }

    func test_multipleSignalWorkers() {
        let (signal, _) = Signal<AnyWorkflowAction<MultipleSignalWorkersWorkflow>, Never>.pipe()
        MultipleSignalWorkersWorkflow(numberOfSignalWorkers: 2)
            .renderTester()
            .expect(worker: SignalWorker(key: 0, signal: signal))
            .expect(worker: SignalWorker(key: 1, signal: signal))
            .render { _ in }
    }
}

@available(*, deprecated)
struct MultipleSignalWorkersWorkflow: Workflow {
    typealias State = Void
    typealias Rendering = Void

    let numberOfSignalWorkers: Int

    func render(state: Void, context: RenderContext<MultipleSignalWorkersWorkflow>) {
        for i in 0 ..< numberOfSignalWorkers {
            let (signal, _) = Signal<AnyWorkflowAction<MultipleSignalWorkersWorkflow>, Never>.pipe()
            context.awaitResult(
                for: signal
                    .asWorker(key: i)
            )
        }
    }
}

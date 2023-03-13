/*
 * Copyright 2023 Square Inc.
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

final class AnyWorkflowActionTests: XCTestCase {
    func testRetainsBaseActionTypeInfo() {
        let action = ExampleAction()
        let erased = AnyWorkflowAction(action)

        XCTAssertEqual(action, erased.base as? ExampleAction)
    }

    func testRetainsClosureActionTypeInfo() throws {
        do {
            let erased = AnyWorkflowAction<ExampleWorkflow> { _ in
                nil
            }

            XCTAssertNotNil(erased.base as? ClosureAction<ExampleWorkflow>)
        }

        do {
            let file = #file
            let line = #line + 1 // must match line # the initializer is on
            let erased = AnyWorkflowAction<ExampleWorkflow> { _ in
                nil
            }

            let closureAction = try XCTUnwrap(erased.base as? ClosureAction<ExampleWorkflow>)
            XCTAssertEqual(closureAction.file, file)
            XCTAssertEqual(closureAction.line, line)
        }
    }

    func testMultipleErasure() {
        // standard init
        do {
            let action = ExampleAction()
            let erasedOnce = AnyWorkflowAction(action)
            let erasedTwice = AnyWorkflowAction(erasedOnce)

            XCTAssertEqual(
                erasedOnce.base as? ExampleAction,
                erasedTwice.base as? ExampleAction
            )
        }

        // closure init
        do {
            let action = AnyWorkflowAction<ExampleWorkflow> { _ in nil }
            let erasedAgain = AnyWorkflowAction(action)

            XCTAssertEqual(
                "\(action.base.self)",
                "\(erasedAgain.base.self)"
            )
        }
    }

    func testApplyForwarding() {
        var log: [String] = []
        let action = ObservableExampleAction {
            log.append("action invoked")
        }

        let erased = AnyWorkflowAction(action)

        XCTAssertEqual(log, [])

        var state: Void = ()
        _ = erased.apply(toState: &state)

        XCTAssertEqual(log, ["action invoked"])
    }
}

private struct ExampleWorkflow: Workflow {
    typealias State = Void
    typealias Output = Never
    typealias Rendering = Void

    func render(state: Void, context: RenderContext<ExampleWorkflow>) {}
}

private struct ExampleAction: WorkflowAction, Equatable {
    typealias WorkflowType = ExampleWorkflow

    func apply(toState state: inout WorkflowType.State) -> WorkflowType.Output? {
        return nil
    }
}

private struct ObservableExampleAction: WorkflowAction {
    typealias WorkflowType = ExampleWorkflow

    var block: () -> Void = {}

    func apply(toState state: inout WorkflowType.State) -> WorkflowType.Output? {
        block()
        return nil
    }
}

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

import XCTest
@testable import Workflow

public class AnyWorkflowRenderingTests: XCTestCase {
    func testRenderingString() {
        let workflow = AnyWorkflow(rendering: "Hello")
        let node = WorkflowNode(workflow: PassthroughWorkflow(workflow))

        XCTAssertEqual(node.render(), "Hello")
    }

    func testRenderingInt() {
        let workflow = AnyWorkflow(rendering: 160)
        let node = WorkflowNode(workflow: PassthroughWorkflow(workflow))

        XCTAssertEqual(node.render(), 160)
    }
}

private struct PassthroughWorkflow<Rendering>: Workflow {
    var child: AnyWorkflow<Rendering, Never>
    init(_ child: AnyWorkflow<Rendering, Never>) {
        self.child = child
    }

    func render(state: Void, context: RenderContext<Self>) -> Rendering {
        child.rendered(in: context)
    }
}

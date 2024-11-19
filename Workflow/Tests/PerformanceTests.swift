/*
 * Copyright 2022 Square Inc.
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

class PerformanceTests: XCTestCase {
    var noOpObserver: WorkflowObserver {
        struct NoOpObserverImpl: WorkflowObserver {}
        return NoOpObserverImpl()
    }

    override func setUp() {
        super.setUp()
        WorkflowLogging.enabled = false
    }

    override func tearDown() {
        super.tearDown()
        WorkflowLogging.enabled = false
    }

    func test_render_wideShallowTree() throws {
        measure {
            let node = WorkflowNode(workflow: WideShallowParentWorkflow())
            _ = node.render(isRootNode: true)
        }
    }

    func test_render_wideShallowTree_withNoOpObserver() throws {
        measure { [noOpObserver] in
            let node = WorkflowNode(
                workflow: WideShallowParentWorkflow(),
                observer: noOpObserver
            )
            _ = node.render(isRootNode: true)
        }
    }

    func test_render_narrowDeepTree() throws {
        measure {
            let node = WorkflowNode(workflow: NarrowDeepParentWorkflow())
            _ = node.render(isRootNode: true)
        }
    }

    func test_render_narrowDeepTree_withNoOpObserver() throws {
        measure { [noOpObserver] in
            let node = WorkflowNode(
                workflow: NarrowDeepParentWorkflow(),
                observer: noOpObserver
            )
            _ = node.render(isRootNode: true)
        }
    }

    func test_debugLogging_render_wideShallowTree() throws {
        WorkflowLogging.enabled = true
        WorkflowLogging.config = .debug

        measure {
            let node = WorkflowNode(workflow: WideShallowParentWorkflow())
            _ = node.render(isRootNode: true)
        }
    }

    func test_rootNodeLogging_render_wideShallowTree() throws {
        WorkflowLogging.enabled = true
        WorkflowLogging.config = .rootRendersAndActions

        measure {
            let node = WorkflowNode(workflow: WideShallowParentWorkflow())
            _ = node.render(isRootNode: true)
        }
    }

    func test_rootNodeLogging_render_narrowDeepTree() throws {
        WorkflowLogging.enabled = true
        WorkflowLogging.config = .rootRendersAndActions

        measure {
            let node = WorkflowNode(workflow: NarrowDeepParentWorkflow())
            _ = node.render(isRootNode: true)
        }
    }
}

extension PerformanceTests {
    fileprivate struct WideShallowParentWorkflow: Workflow {
        typealias State = Void
        typealias Rendering = Int

        func render(state: Void, context: RenderContext<WideShallowParentWorkflow>) -> Int {
            var sum = 0
            for i in 1 ... 1000 {
                sum += ChildWorkflow()
                    .rendered(in: context, key: "child-\(i)")
            }

            return sum
        }
    }

    fileprivate struct NarrowDeepParentWorkflow: Workflow {
        typealias State = Void
        typealias Rendering = Int

        func render(state: Void, context: RenderContext<NarrowDeepParentWorkflow>) -> Int {
            var sum = 0
            sum += ChildWorkflow(remainingChildren: 999)
                .rendered(in: context)

            return sum
        }
    }

    fileprivate struct ChildWorkflow: Workflow {
        typealias State = Void
        typealias Rendering = Int

        var remainingChildren: UInt = 0

        func render(state: Void, context: RenderContext<ChildWorkflow>) -> Int {
            let rendering: Int = if remainingChildren > 0 {
                ChildWorkflow(remainingChildren: remainingChildren - 1)
                    .rendered(in: context)
            } else {
                42
            }

            return rendering
        }
    }
}

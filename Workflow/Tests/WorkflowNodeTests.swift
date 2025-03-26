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

final class WorkflowNodeTests: XCTestCase {
    func test_rendersSimpleWorkflow() {
        let node = WorkflowNode(workflow: SimpleWorkflow(string: "Foo"))
        XCTAssertEqual(node.render(), "ooF")
    }

    func test_rendersNestedWorkflows() {
        let node = WorkflowNode(
            workflow: CompositeWorkflow(
                a: SimpleWorkflow(string: "Hello"),
                b: SimpleWorkflow(string: "World")
            ))

        XCTAssertEqual(node.render().aRendering, "olleH")
        XCTAssertEqual(node.render().bRendering, "dlroW")
    }

    func test_childWorkflowsEmitOutputEvents() {
        typealias WorkflowType = CompositeWorkflow<EventEmittingWorkflow, SimpleWorkflow>

        let workflow = CompositeWorkflow(
            a: EventEmittingWorkflow(string: "Hello"),
            b: SimpleWorkflow(string: "World")
        )

        let node = WorkflowNode(workflow: workflow)

        let rendering = node.render()
        node.enableEvents()

        var outputs: [WorkflowType.Output] = []

        let expectation = XCTestExpectation(description: "Node output")

        node.onOutput = { value in
            if let output = value.outputEvent {
                outputs.append(output)
                expectation.fulfill()
            }
        }

        rendering.aRendering.someoneTappedTheButton()

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(outputs, [WorkflowType.Output.childADidSomething(.helloWorld)])
    }

    func test_childWorkflowsEmitStateChangeEvents() {
        typealias WorkflowType = CompositeWorkflow<StateTransitioningWorkflow, SimpleWorkflow>

        let workflow = CompositeWorkflow(
            a: StateTransitioningWorkflow(),
            b: SimpleWorkflow(string: "World")
        )

        let node = WorkflowNode(workflow: workflow)

        let expectation = XCTestExpectation(description: "State Change")
        var stateChangeCount = 0

        node.onOutput = { _ in
            stateChangeCount += 1
            if stateChangeCount == 3 {
                expectation.fulfill()
            }
        }

        var aRendering = node.render().aRendering
        node.enableEvents()
        aRendering.toggle()

        aRendering = node.render().aRendering
        node.enableEvents()
        aRendering.toggle()

        aRendering = node.render().aRendering
        node.enableEvents()
        aRendering.toggle()

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(stateChangeCount, 3)
    }

    func test_debugUpdateInfo() {
        typealias WorkflowType = CompositeWorkflow<EventEmittingWorkflow, SimpleWorkflow>

        let workflow = CompositeWorkflow(
            a: EventEmittingWorkflow(string: "Hello"),
            b: SimpleWorkflow(string: "World")
        )

        let context = HostContext.testing(debugger: TestDebugger())
        let node = WorkflowNode(workflow: workflow, hostContext: context)

        let rendering = node.render()
        node.enableEvents()

        var emittedDebugInfo: [WorkflowUpdateDebugInfo?] = []

        let expectation = XCTestExpectation(description: "Output")
        node.onOutput = { value in
            emittedDebugInfo.append(value.debugInfo)
            expectation.fulfill()
        }

        rendering.aRendering.someoneTappedTheButton()

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(emittedDebugInfo.count, 1)

        let debugInfo = emittedDebugInfo[0]
        XCTAssert(debugInfo?.workflowType == "\(WorkflowType.self)")

        /// Test the shape of the emitted debug info
        switch debugInfo?.kind {
        case .none:
            XCTFail()
        case .childDidUpdate:
            XCTFail()
        case .didUpdate(let source):
            switch source {
            case .external, .worker, .sideEffect:
                XCTFail()
            case .subtree(let childInfo):
                XCTAssert(childInfo.workflowType == "\(EventEmittingWorkflow.self)")
                switch childInfo.kind {
                case .childDidUpdate:
                    XCTFail()
                case .didUpdate(let source):
                    switch source {
                    case .external:
                        break
                    case .subtree(_), .worker, .sideEffect:
                        XCTFail()
                    }
                }
            }
        }
    }

    func test_debugTreeSnapshots() {
        typealias WorkflowType = CompositeWorkflow<EventEmittingWorkflow, SimpleWorkflow>

        let workflow = CompositeWorkflow(
            a: EventEmittingWorkflow(string: "Hello"),
            b: SimpleWorkflow(string: "World")
        )
        let node = WorkflowNode(workflow: workflow)
        _ = node.render() // the debug snapshow always reflects the tree after the latest render pass

        let snapshot = node.makeDebugSnapshot()

        let expectedSnapshot = WorkflowHierarchyDebugSnapshot(
            workflowType: "\(WorkflowType.self)",
            stateDescription: "\(WorkflowType.State())",
            children: [
                WorkflowHierarchyDebugSnapshot.Child(
                    key: "a",
                    snapshot: WorkflowHierarchyDebugSnapshot(
                        workflowType: "\(EventEmittingWorkflow.self)",
                        stateDescription: "\(EventEmittingWorkflow.State())"
                    )
                ),
                WorkflowHierarchyDebugSnapshot.Child(
                    key: "b",
                    snapshot: WorkflowHierarchyDebugSnapshot(
                        workflowType: "\(SimpleWorkflow.self)",
                        stateDescription: "\(SimpleWorkflow.State())"
                    )
                ),
            ]
        )

        XCTAssertEqual(snapshot, expectedSnapshot)
    }

    func test_sessionCreation_init() {
        let workflow = SimpleWorkflow(string: "abc")

        let node = WorkflowNode(
            workflow: workflow,
            key: "key",
            parentSession: nil,
            observer: nil
        )

        let session = node.session

        XCTAssertNil(session.parent)
        XCTAssertEqual(session.renderKey, "key")
        XCTAssertEqual("\(session.workflowType)", "\(SimpleWorkflow.self)")
    }

    func test_sessionCreation_render() {
        let workflow = CompositeWorkflow(
            a: SimpleWorkflow(string: "left"),
            b: EventEmittingWorkflow(string: "right")
        )

        let sessionCollector = SessionCollectingObserver()

        let node = WorkflowNode(
            workflow: workflow,
            observer: sessionCollector
        )

        XCTAssertEqual(sessionCollector.sessions.count, 1)

        _ = node.render()

        let sessions = sessionCollector.sessions

        XCTAssertEqual(sessions.count, 3)
        XCTAssertNotNil(sessions[0].workflowType is CompositeWorkflow<SimpleWorkflow, EventEmittingWorkflow>.Type)
        XCTAssertTrue(sessions[1].workflowType is SimpleWorkflow.Type)
        XCTAssertTrue(sessions[2].workflowType is EventEmittingWorkflow.Type)
        XCTAssertEqual(sessions[0].sessionID, sessions[1].parent?.sessionID)
    }

    func test_isRootNode() {
        do {
            let root = WorkflowNode(workflow: SimpleWorkflow(string: "root"))
            XCTAssert(root.isRootNode)
        }

        do {
            let parentSession = WorkflowSession(
                workflow: SimpleWorkflow(string: "parent"),
                renderKey: "",
                parent: nil
            )
            let root = WorkflowNode(
                workflow: SimpleWorkflow(string: "root"),
                parentSession: parentSession
            )
            XCTAssertFalse(root.isRootNode)
        }
    }
}

/// Renders two child state machines of types `A` and `B`.
private struct CompositeWorkflow<A, B>: Workflow where
    A: Workflow,
    B: Workflow
{
    var a: A
    var b: B
}

extension CompositeWorkflow {
    struct State {}

    struct Rendering {
        var aRendering: A.Rendering
        var bRendering: B.Rendering
    }

    enum Output {
        case childADidSomething(A.Output)
        case childBDidSomething(B.Output)
    }

    enum Event: WorkflowAction {
        case a(A.Output)
        case b(B.Output)

        typealias WorkflowType = CompositeWorkflow<A, B>

        func apply(toState state: inout CompositeWorkflow<A, B>.State) -> CompositeWorkflow<A, B>.Output? {
            switch self {
            case .a(let childOutput):
                .childADidSomething(childOutput)
            case .b(let childOutput):
                .childBDidSomething(childOutput)
            }
        }
    }

    func makeInitialState() -> CompositeWorkflow<A, B>.State {
        State()
    }

    func render(state: State, context: RenderContext<CompositeWorkflow<A, B>>) -> Rendering {
        Rendering(
            aRendering: a
                .mapOutput { Event.a($0) }
                .rendered(in: context, key: "a"),
            bRendering: b
                .mapOutput { Event.b($0) }
                .rendered(in: context, key: "b")
        )
    }
}

extension CompositeWorkflow.Rendering: Equatable where A.Rendering: Equatable, B.Rendering: Equatable {
    fileprivate static func == (lhs: CompositeWorkflow.Rendering, rhs: CompositeWorkflow.Rendering) -> Bool {
        lhs.aRendering == rhs.aRendering
            && lhs.bRendering == rhs.bRendering
    }
}

extension CompositeWorkflow.Output: Equatable where A.Output: Equatable, B.Output: Equatable {
    fileprivate static func == (lhs: CompositeWorkflow.Output, rhs: CompositeWorkflow.Output) -> Bool {
        switch (lhs, rhs) {
        case (.childADidSomething(let l), .childADidSomething(let r)):
            l == r
        case (.childBDidSomething(let l), .childBDidSomething(let r)):
            l == r
        default:
            false
        }
    }
}

/// Has no state or output, simply renders a reversed string
private struct SimpleWorkflow: Workflow {
    var string: String

    struct State {}

    func makeInitialState() -> State {
        State()
    }

    func render(state: State, context: RenderContext<SimpleWorkflow>) -> String {
        String(string.reversed())
    }
}

/// Renders to a model that contains a callback, which in turn sends an output event.
private struct EventEmittingWorkflow: Workflow {
    var string: String
}

extension EventEmittingWorkflow {
    struct State {}

    struct Rendering {
        var someoneTappedTheButton: () -> Void
    }

    func makeInitialState() -> State {
        State()
    }

    enum Event: Equatable, WorkflowAction {
        case tapped

        typealias WorkflowType = EventEmittingWorkflow

        func apply(toState state: inout EventEmittingWorkflow.State) -> EventEmittingWorkflow.Output? {
            switch self {
            case .tapped:
                .helloWorld
            }
        }
    }

    enum Output: Equatable {
        case helloWorld
    }

    func render(state: State, context: RenderContext<EventEmittingWorkflow>) -> Rendering {
        let sink = context.makeSink(of: Event.self)

        return Rendering(someoneTappedTheButton: { sink.send(.tapped) })
    }
}

private class SessionCollectingObserver: WorkflowObserver {
    var sessions: [WorkflowSession] = []

    func sessionDidBegin(_ session: WorkflowSession) {
        sessions.append(session)
    }
}

#if compiler(>=5.0)
// Never gains Equatable and Hashable conformance in Swift 5
#else
extension Never: Equatable {}
#endif

// MARK: -

extension WorkflowNode {
    convenience init(
        workflow: WorkflowType,
        key: String = "",
        parentSession: WorkflowSession? = nil,
        observer: WorkflowObserver? = nil
    ) {
        self.init(
            workflow: workflow,
            key: key,
            hostContext: HostContext.testing(observer: observer),
            parentSession: parentSession
        )
    }
}

// MARK: -

private struct TestDebugger: WorkflowDebugger {
    func didEnterInitialState(
        snapshot: WorkflowHierarchyDebugSnapshot
    ) {}

    func didUpdate(
        snapshot: WorkflowHierarchyDebugSnapshot,
        updateInfo: WorkflowUpdateDebugInfo
    ) {}
}

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

@testable @_spi(WorkflowGlobalObservation) import Workflow

final class WorkflowObserverTests: XCTestCase {
    private var observer: TestObserver!

    override func setUp() {
        super.setUp()
        observer = TestObserver()
        WorkflowObservation.sharedObserversInterceptor = nil
    }

    // MARK: Basic Callback Validations

    func test_sessionLifecycleCallbacks() {
        var sessionBeganCount = 0
        var beganSession: WorkflowSession?
        var endedSession: WorkflowSession?
        observer.onSessionBegan = { session in
            beganSession = session
            sessionBeganCount += 1
        }

        var sessionEndedCount = 0
        observer.onSessionEnded = { session in
            endedSession = session
            sessionEndedCount += 1
        }

        weak var weakHost: WorkflowHost<StateTransitioningWorkflow>?

        // session end happens in deinit, so need control over release timing
        autoreleasepool {
            let host = WorkflowHost(
                workflow: StateTransitioningWorkflow(),
                observers: [observer]
            )
            weakHost = host
        }

        XCTAssertNil(weakHost, "host expected to deallocate")
        XCTAssertNotNil(beganSession)
        XCTAssertNotNil(beganSession?.sessionID)
        XCTAssertEqual(beganSession?.sessionID, endedSession?.sessionID)
        XCTAssertEqual(sessionBeganCount, 1)
        XCTAssertEqual(sessionEndedCount, 1)
    }

    func test_makeInitialStateCallbacks() {
        var sessions: [WorkflowSession] = []
        observer.onDidMakeInitialState = { workflow, state, session in
            sessions.append(session)
        }

        _ = WorkflowHost(
            workflow: Parent(),
            observers: [observer]
        )

        XCTAssertEqual(
            sessions.map(\.workflowTypeString),
            ["\(Parent.self)", "\(Child.self)"]
        )
    }

    func test_renderCallbacks() {
        var willRenderSessions: [WorkflowSession] = []
        var didRenderSessions: [WorkflowSession] = []
        observer.onWillRender = { workflow, state, session in
            willRenderSessions.append(session)

            return { rendering in
                didRenderSessions.append(session)
            }
        }

        let node = WorkflowNode(
            workflow: Parent(),
            parentSession: nil,
            observer: observer
        )

        _ = node.render()

        XCTAssertEqual(
            willRenderSessions.map(\.workflowTypeString),
            ["\(Parent.self)", "\(Child.self)"]
        )

        XCTAssertEqual(
            didRenderSessions.map(\.workflowTypeString),
            ["\(Child.self)", "\(Parent.self)"]
        )
    }

    func test_didChangeCallbacks() {
        var didChangeCallCount = 0
        observer.onDidChange = { old, new, state, session in
            guard old is Child, new is Child else {
                XCTFail("unexpected workflow type. expecting values of \(Child.self), got: \(type(of: old)) (old workflow), \(type(of: new)) (new workflow)")
                return
            }

            didChangeCallCount += 1
        }

        let node = WorkflowNode(
            workflow: Parent(),
            parentSession: nil,
            observer: observer
        )

        _ = node.render()

        XCTAssertEqual(didChangeCallCount, 0)

        _ = node.render()

        XCTAssertEqual(didChangeCallCount, 1)
    }

    func test_didReceiveActionCallbacks() {
        var actions: [StateTransitioningWorkflow.Event] = []
        observer.onDidReceiveAction = { action, workflow, session in
            guard let action = action as? StateTransitioningWorkflow.Event else {
                XCTFail("unexpected action. expecting \(StateTransitioningWorkflow.Event.self), got \(type(of: action))")
                return
            }

            actions.append(action)
        }

        let node = WorkflowNode(
            workflow: StateTransitioningWorkflow(),
            parentSession: nil,
            observer: observer
        )

        let rendering = node.render()
        node.enableEvents()

        XCTAssertEqual(actions, [])

        rendering.toggle()

        XCTAssertEqual(actions, [.toggle])
    }

    func test_willApplyActionCallbacks() {
        var willApplyActions: [StateTransitioningWorkflow.Event] = []
        var didApplyActions: [StateTransitioningWorkflow.Event] = []
        var willApplyState: Bool?
        var didApplyState: Bool?

        observer.onApplyAction = { action, workflow, state, session in
            let anyAction = action as? AnyWorkflowAction<StateTransitioningWorkflow>
            guard let action: StateTransitioningWorkflow.Event = anyAction?.getWrappedValue() else {
                XCTFail("unexpected action. expecting \(StateTransitioningWorkflow.Event.self), got \(type(of: action))")
                return nil
            }

            willApplyState = state as? Bool
            willApplyActions.append(action)

            return { state, output in
                didApplyState = state as? Bool
                didApplyActions.append(action)
            }
        }

        let node = WorkflowNode(
            workflow: StateTransitioningWorkflow(),
            parentSession: nil,
            observer: observer
        )

        let rendering = node.render()
        node.enableEvents()

        XCTAssertEqual(willApplyActions, [])
        XCTAssertEqual(didApplyActions, [])

        rendering.toggle()

        XCTAssertEqual(willApplyState, false)
        XCTAssertEqual(didApplyState, true)
        XCTAssertEqual(willApplyActions, [.toggle])
        XCTAssertEqual(didApplyActions, [.toggle])
    }
}

// MARK: - ChainedObserver

extension WorkflowObserverTests {
    func test_chainedObserver_sessionBegin() {
        var callbackSequence: [String] = []

        let observer1 = TestObserver()
        observer1.onSessionBegan = { _ in
            callbackSequence.append("one")
        }

        let observer2 = TestObserver()
        observer2.onSessionBegan = { _ in
            callbackSequence.append("two")
        }

        let chained = ChainedWorkflowObserver(observers: [observer1, observer2])
        chained.sessionDidBegin(.testingSession)

        XCTAssertEqual(
            callbackSequence,
            ["one", "two"]
        )
    }

    func test_chainedObserver_sessionEnd() {
        var callbackSequence: [String] = []

        let observer1 = TestObserver()
        observer1.onSessionEnded = { _ in
            callbackSequence.append("one")
        }

        let observer2 = TestObserver()
        observer2.onSessionEnded = { _ in
            callbackSequence.append("two")
        }

        let chained = ChainedWorkflowObserver(observers: [observer1, observer2])
        chained.sessionDidEnd(.testingSession)

        XCTAssertEqual(
            callbackSequence,
            ["one", "two"]
        )
    }

    func test_chainedObserver_makeInitialStateCallbacks() {
        var callbackSequence: [String] = []

        let observer1 = TestObserver()
        observer1.onDidMakeInitialState = { _, _, _ in
            callbackSequence.append("one")
        }

        let observer2 = TestObserver()
        observer2.onDidMakeInitialState = { _, _, _ in
            callbackSequence.append("two")
        }

        let chained = ChainedWorkflowObserver(observers: [observer1, observer2])
        chained.workflowDidMakeInitialState(
            Parent(),
            initialState: (),
            session: .testingSession
        )

        XCTAssertEqual(
            callbackSequence,
            ["one", "two"]
        )
    }

    func test_chainedObserver_renderCallbacks() {
        var willRenderCallbackSequence: [String] = []
        var didRenderCallbackSequence: [String] = []

        let observer1 = TestObserver()
        observer1.onWillRender = { _, _, _ in
            willRenderCallbackSequence.append("one")
            return { _ in
                didRenderCallbackSequence.append("one")
            }
        }

        let observer2 = TestObserver()
        observer2.onWillRender = { _, _, _ in
            willRenderCallbackSequence.append("two")
            return { _ in
                didRenderCallbackSequence.append("two")
            }
        }

        let chained = ChainedWorkflowObserver(observers: [observer1, observer2])
        let didRender = chained.workflowWillRender(
            Parent(),
            state: (),
            session: .testingSession
        )

        XCTAssertEqual(
            willRenderCallbackSequence,
            ["one", "two"]
        )
        XCTAssertEqual(
            didRenderCallbackSequence,
            []
        )

        didRender?(42)

        XCTAssertEqual(
            didRenderCallbackSequence,
            ["two", "one"]
        )
    }

    func test_chainedObserver_didChangeCallbacks() {
        var callbackSequence: [String] = []

        let observer1 = TestObserver()
        observer1.onDidChange = { _, _, _, _ in
            callbackSequence.append("one")
        }

        let observer2 = TestObserver()
        observer2.onDidChange = { _, _, _, _ in
            callbackSequence.append("two")
        }

        let chained = ChainedWorkflowObserver(observers: [observer1, observer2])
        chained.workflowDidChange(
            from: Parent(),
            to: Parent(),
            state: (),
            session: .testingSession
        )

        XCTAssertEqual(
            callbackSequence,
            ["one", "two"]
        )
    }

    func test_chainedObserver_didReceiveActionCallbacks() {
        var callbackSequence: [String] = []

        let observer1 = TestObserver()
        observer1.onDidReceiveAction = { action, workflow, session in
            callbackSequence.append("one")
        }

        let observer2 = TestObserver()
        observer2.onDidReceiveAction = { _, _, _ in
            callbackSequence.append("two")
        }

        let chained = ChainedWorkflowObserver(observers: [observer1, observer2])
        chained.workflowDidReceiveAction(
            StateTransitioningWorkflow.Event.toggle,
            workflow: StateTransitioningWorkflow(),
            session: .testingSession
        )

        XCTAssertEqual(
            callbackSequence,
            ["one", "two"]
        )
    }

    func test_chainedObserver_willApplyActionCallbacks() {
        var willApplyCallbackSequence: [String] = []
        var didApplyCallbackSequence: [String] = []

        let observer1 = TestObserver()
        observer1.onApplyAction = { _, _, _, _ in
            willApplyCallbackSequence.append("one")
            return { _, _ in
                didApplyCallbackSequence.append("one")
            }
        }

        let observer2 = TestObserver()
        observer2.onApplyAction = { _, _, _, _ in
            willApplyCallbackSequence.append("two")
            return { _, _ in
                didApplyCallbackSequence.append("two")
            }
        }

        let chained = ChainedWorkflowObserver(observers: [observer1, observer2])
        let didApply = chained.workflowWillApplyAction(
            StateTransitioningWorkflow.Event.toggle,
            workflow: StateTransitioningWorkflow(),
            state: false,
            session: .testingSession
        )

        XCTAssertEqual(willApplyCallbackSequence, ["one", "two"])
        XCTAssertEqual(didApplyCallbackSequence, [])

        didApply?(true, nil)

        XCTAssertEqual(didApplyCallbackSequence, ["two", "one"])
    }
}

// MARK: - Integration Points

extension WorkflowObserverTests {
    func test_workflowHost_chainsObservers() {
        // 0 observers
        do {
            let host = WorkflowHost(
                workflow: Parent(),
                observers: []
            )

            XCTAssertNil(host.rootNode.observer)
        }

        // 1 observer
        do {
            let host = WorkflowHost(
                workflow: Parent(),
                observers: [TestObserver()]
            )

            XCTAssert(host.rootNode.observer is TestObserver)
        }

        // > 1 observer
        do {
            struct NoOpObserver: WorkflowObserver {}

            let host = WorkflowHost(
                workflow: Parent(),
                observers: [TestObserver(), NoOpObserver()]
            )

            let observer = host.rootNode.observer as? ChainedWorkflowObserver
            XCTAssertNotNil(observer)

            XCTAssertEqual(observer?.observers.count, 2)
            XCTAssert(observer?.observers.first is TestObserver)
            XCTAssert(observer?.observers.last is NoOpObserver)
        }
    }
}

// MARK: - Observer Intercepting

extension WorkflowObserverTests {
    func test_sharedInterceptor() {
        var invocations: [String] = []

        let testObserver1 = TestObserver()
        testObserver1.onSessionBegan = { _ in
            invocations.append("observer 1")
        }

        let testObserver2 = TestObserver()
        testObserver2.onSessionBegan = { _ in
            invocations.append("observer 2")
        }

        WorkflowObservation.sharedObserversInterceptor = DefaultObservers(observers: [testObserver2])

        _ = WorkflowHost(
            workflow: Child(prop: ""),
            observers: [testObserver1]
        )

        XCTAssertEqual(invocations, [
            "observer 2",
            "observer 1",
        ])
    }

    func test_sharedInterceptor_reset() {
        var invocations: [String] = []

        let globalObserver = TestObserver()
        globalObserver.onSessionBegan = { _ in
            invocations.append("global observer")
        }

        let localObserver = TestObserver()
        localObserver.onSessionBegan = { _ in
            invocations.append("local observer")
        }

        XCTContext.runActivity(named: "custom interceptor") { _ in
            WorkflowObservation.sharedObserversInterceptor = DefaultObservers(observers: [globalObserver])

            _ = WorkflowHost(
                workflow: Child(prop: ""),
                observers: [localObserver]
            )

            XCTAssertEqual(invocations, [
                "global observer",
                "local observer",
            ])
        }

        XCTContext.runActivity(named: "default interceptor") { _ in
            invocations = []
            WorkflowObservation.sharedObserversInterceptor = nil

            _ = WorkflowHost(
                workflow: Child(prop: ""),
                observers: [localObserver]
            )

            XCTAssertEqual(invocations, [
                "local observer",
            ])
        }
    }
}

// MARK: - Utilities

private final class TestObserver: WorkflowObserver {
    var onSessionBegan: ((WorkflowSession) -> Void)?
    var onSessionEnded: ((WorkflowSession) -> Void)?
    /// (Workflow, State, Session) -> Void
    var onDidMakeInitialState: ((Any, Any, WorkflowSession) -> Void)?
    /// (Workflow, State, Session) -> ((Rendering) -> Void)?
    var onWillRender: ((Any, Any, WorkflowSession) -> ((Any) -> Void)?)?
    /// (Workflow [old], Workflow [new], State, Session) -> Void
    var onDidChange: ((Any, Any, Any, WorkflowSession) -> Void)?
    /// (Action, Workflow, Session) -> Void
    var onDidReceiveAction: ((Any, Any, WorkflowSession) -> Void)?
    /// (Action, Workflow, State, Session) -> ((State, Output?) -> Void)?
    var onApplyAction: ((Any, Any, Any, WorkflowSession) -> ((Any, Any) -> Void)?)?

    func sessionDidBegin(_ session: WorkflowSession) {
        onSessionBegan?(session)
    }

    func sessionDidEnd(_ session: WorkflowSession) {
        onSessionEnded?(session)
    }

    func workflowDidMakeInitialState<WorkflowType>(
        _ workflow: WorkflowType,
        initialState: WorkflowType.State,
        session: WorkflowSession
    ) where WorkflowType: Workflow {
        onDidMakeInitialState?(workflow, initialState, session)
    }

    func workflowWillRender<WorkflowType>(_ workflow: WorkflowType, state: WorkflowType.State, session: WorkflowSession) -> ((WorkflowType.Rendering) -> Void)? where WorkflowType: Workflow {
        onWillRender?(workflow, state, session)
    }

    func workflowDidChange<WorkflowType>(from oldWorkflow: WorkflowType, to newWorkflow: WorkflowType, state: WorkflowType.State, session: WorkflowSession) where WorkflowType: Workflow {
        onDidChange?(oldWorkflow, newWorkflow, state, session)
    }

    func workflowDidReceiveAction<Action>(_ action: Action, workflow: Action.WorkflowType, session: WorkflowSession) where Action: WorkflowAction {
        onDidReceiveAction?(action, workflow, session)
    }

    func workflowWillApplyAction<Action>(_ action: Action, workflow: Action.WorkflowType, state: Action.WorkflowType.State, session: WorkflowSession) -> ((Action.WorkflowType.State, Action.WorkflowType.Output?) -> Void)? where Action: WorkflowAction {
        onApplyAction?(action, workflow, state, session)
    }
}

private struct Child: Workflow {
    var prop: String

    func render(state: Void, context: RenderContext<Child>) -> String {
        return prop
    }
}

private struct Parent: Workflow {
    var renderCount = 0

    func render(state: Void, context: RenderContext<Parent>) -> Int {
        _ = Child(prop: "child")
            .rendered(in: context)

        return renderCount
    }
}

private extension WorkflowSession {
    var workflowTypeString: String { String(describing: workflowType) }

    static var testingSession: Self {
        WorkflowSession(
            workflow: Parent(),
            renderKey: "",
            parent: nil
        )
    }
}

extension AnyWorkflowAction {
    func getWrappedValue<T: WorkflowAction>() -> T? {
        _wrappedValue as? T
    }
}

private struct DefaultObservers: ObserversInterceptor {
    var observers: [WorkflowObserver]

    func workflowObservers(for initialObservers: [WorkflowObserver]) -> [WorkflowObserver] {
        observers + initialObservers
    }
}

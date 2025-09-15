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

import ReactiveSwift
import XCTest

@_spi(WorkflowRuntimeConfig) @testable import Workflow

final class WorkflowHostTests: XCTestCase {
    func test_updatedInputCausesRenderPass() {
        let host = WorkflowHost(workflow: TestWorkflow(step: .first))

        XCTAssertEqual(1, host.rendering.value)

        host.update(workflow: TestWorkflow(step: .second))

        XCTAssertEqual(2, host.rendering.value)
    }

    fileprivate struct TestWorkflow: Workflow {
        var step: Step
        enum Step {
            case first
            case second
        }

        struct State {}
        func makeInitialState() -> State {
            State()
        }

        typealias Rendering = Int

        func render(state: State, context: RenderContext<TestWorkflow>) -> Rendering {
            switch step {
            case .first:
                1
            case .second:
                2
            }
        }
    }
}

// MARK: Event Emission Tests

final class WorkflowHost_EventEmissionTests: XCTestCase {
    // Previous versions of Workflow would fatalError under this scenario
    func test_event_sent_to_invalidated_sink_during_action_handling() {
        let root = Parent()
        let host = WorkflowHost(workflow: root)
        let initialRendering = host.rendering.value
        var observedRenderCount = 0

        XCTAssertEqual(initialRendering.eventCount, 0)

        let disposable = host.rendering.signal.observeValues { rendering in
            XCTAssertEqual(rendering.eventCount, 1)

            // emit another event using an old rendering
            // while the first is still being processed, but
            // the workflow that handles the event has been
            // removed from the tree
            if observedRenderCount == 0 {
                initialRendering.eventHandler()
            }

            observedRenderCount += 1
        }
        defer { disposable?.dispose() }

        // send an event and cause a re-render
        initialRendering.eventHandler()

        XCTAssertEqual(observedRenderCount, 1)
    }

    func test_reentrant_event_emission_in_update() {
        let root = Parent()
        let host = WorkflowHost(workflow: root)
        let (lt, token) = ReactiveSwift.Lifetime.make()
        defer { withExtendedLifetime(token) {} }
        let initialRendering = host.rendering.value
        var observedRenderCount = 0

        XCTAssertEqual(initialRendering.eventCount, 0)

        let queuedEvent = expectation(description: "queued event")

        let disposable = host.rendering.signal
            .take(during: lt)
//            .on(value: { rendering in
            .observeValues { rendering in
                XCTAssertEqual(rendering.eventCount, 1)

                // Force an update synchronously in render
                if observedRenderCount == 0 {
                    host.update(workflow: Parent())
                    let newRendering = host.rendering.value

                    // Queue an update into the new rendering, but spin
                    // the RunLoop to force it to be handled 'synchronously'
                    DispatchQueue.main.async {
                        newRendering.eventHandler()
                        queuedEvent.fulfill()
                    }

                    // spin the run loop manually
                    self.wait(for: [queuedEvent], timeout: 1)
                }

                observedRenderCount += 1
            }
//            })
//            .observeValues { _ in }
        defer { disposable?.dispose() }

        // send an event and cause a re-render
        initialRendering.eventHandler()

        XCTAssertEqual(observedRenderCount, 1)
    }

    func test_reentrant_event_emission_in_update2() {
        let root = ReentrancyWorkflow()
        let host = WorkflowHost(workflow: root)
        let (lt, token) = ReactiveSwift.Lifetime.make()
        defer { withExtendedLifetime(token) {} }
        let initialRendering = host.rendering.value

        var emitReentrantEvent = false

        host
            .rendering
            .signal
            .take(during: lt)
            .observeValues { val in
                defer { emitReentrantEvent = true }
                guard !emitReentrantEvent else { return }

                // In a prior implementation, this would check state local
                // to the underlying EventPipe and defer event handling
                // into the future. If the RunLoop was spun after that
                // point, the action would attempt to be handled and an
                // invariant about sending a sink an action in an invalid
                // state would be hit.
                //
                // 'Real world' code can hit this case as there are some
                // UI bindings that fire when a rendering/output is updated
                // that call into system API that do sometimes spin the
                // RunLoop manually (e.g. stuff calling into WebKit).
                initialRendering.sink2?.send(.two)
                spinRunLoopFn()
            }

        // send an event and cause a re-render
        initialRendering.sink1?.send(.one)

        XCTAssert(emitReentrantEvent)
    }
}

func spinRunLoopFn() {
    var done = false

    DispatchQueue.main.async {
        done = true
    }

    while !done {
        RunLoop.current.run(until: .now.addingTimeInterval(0.01))
    }
}

// MARK: Runtime Configuration

extension WorkflowHostTests {
    func test_inherits_default_runtime_config() {
        let host = WorkflowHost(
            workflow: TestWorkflow(step: .first)
        )

        XCTAssertEqual(host.context.runtimeConfig, .default)
    }

    func test_inherits_custom_runtime_config() {
        var customConfig = Runtime.configuration
        XCTAssertFalse(customConfig.renderOnlyIfStateChanged)

        customConfig.renderOnlyIfStateChanged = true
        let host = Runtime.$_currentConfiguration.withValue(customConfig) {
            WorkflowHost(
                workflow: TestWorkflow(step: .first)
            )
        }

        XCTAssertEqual(host.context.runtimeConfig.renderOnlyIfStateChanged, true)
    }
}

// MARK: Utility Types

extension WorkflowHost_EventEmissionTests {
    struct ReentrancyWorkflow: Workflow {
        struct Rendering {
            var sink1: Sink<Action1>?
            var sink2: Sink<Action2>?
        }

        typealias State = Void
        typealias Output = String

        var spinRunLoop: Bool = false

        func render(state: Void, context: RenderContext<Self>) -> Rendering {
            let sink1 = context.makeSink(of: Action1.self)
            let sink2 = context.makeSink(of: Action2.self)

//            if spinRunLoop {
//                spinRunLoopFn()
//            }

            return Rendering(sink1: sink1, sink2: sink2)
        }
    }

    enum Action1: WorkflowAction {
        typealias WorkflowType = ReentrancyWorkflow
        case one

        func apply(
            toState state: inout WorkflowType.State,
            context: ApplyContext<WorkflowType>
        ) -> WorkflowType.Output? {
            "one"
        }
    }

    enum Action2: WorkflowAction {
        typealias WorkflowType = ReentrancyWorkflow
        case two

        func apply(
            toState state: inout WorkflowType.State,
            context: ApplyContext<WorkflowType>
        ) -> WorkflowType.Output? {
//            "two"
            nil
        }
    }
}

extension WorkflowHost_EventEmissionTests {
    struct Parent: Workflow {
        struct Rendering {
            var eventCount = 0
            var eventHandler: () -> Void
        }

        typealias Output = Never

        struct State {
            var renderFirst = true
            var eventCount = 0
        }

        func makeInitialState() -> State { .init() }

        func render(state: State, context: RenderContext<Parent>) -> Rendering {
            // swap which child is rendered
            let key = state.renderFirst ? "first" : "second"
            let handler = Child()
                .mapOutput { _ in
                    ParentAction.childChanged
                }
                .rendered(in: context, key: key)

            return Rendering(
                eventCount: state.eventCount,
                eventHandler: handler
            )
        }

        enum ParentAction: WorkflowAction {
            typealias WorkflowType = Parent

            case childChanged

            func apply(toState state: inout Parent.State, context: ApplyContext<WorkflowType>) -> Never? {
                state.eventCount += 1
                state.renderFirst.toggle()
                return nil
            }
        }
    }

    struct Child: Workflow {
        typealias Rendering = () -> Void
        typealias State = Void
        enum Output {
            case eventOccurred
        }

        func render(state: Void, context: RenderContext<Child>) -> () -> Void {
            let sink = context.makeSink(of: Action.self)
            return { sink.send(Action.eventOccurred) }
        }

        enum Action: WorkflowAction {
            typealias WorkflowType = Child

            case eventOccurred

            func apply(toState state: inout Void, context: ApplyContext<WorkflowType>) -> Child.Output? {
                .eventOccurred
            }
        }
    }
}

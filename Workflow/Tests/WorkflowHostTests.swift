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
        let host = WorkflowHost(workflow: Parent())
        let (lifetime, token) = ReactiveSwift.Lifetime.make()
        defer { _ = token }
        let initialRendering = host.rendering.value
        var observedRenderCount = 0

        XCTAssertEqual(initialRendering.eventCount, 0)

        host
            .rendering
            .signal
            .take(during: lifetime)
            .observeValues { rendering in
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

        // send an event and cause a re-render
        initialRendering.eventHandler()

        XCTAssertEqual(observedRenderCount, 1)

        drainMainQueueBySpinningRunLoop()

        // Ensure the invalidated sink doesn't process the event
        let nextRendering = host.rendering.value
        XCTAssertEqual(nextRendering.eventCount, 1)
        XCTAssertEqual(observedRenderCount, 1)
    }

    func test_reentrant_event_during_render() {
        let host = WorkflowHost(workflow: ReentrancyWorkflow())
        let (lifetime, token) = ReactiveSwift.Lifetime.make()
        defer { _ = token }
        let initialRendering = host.rendering.value

        var emitReentrantEvent = false

        let renderExpectation = expectation(description: "render")
        renderExpectation.expectedFulfillmentCount = 2

        var observedRenderCount = 0

        host
            .rendering
            .signal
            .take(during: lifetime)
            .observeValues { val in
                observedRenderCount += 1

                defer { renderExpectation.fulfill() }
                guard !emitReentrantEvent else { return }
                emitReentrantEvent = true

                // In a prior implementation, this would check state local
                // to the underlying EventPipe and defer event handling
                // into the future. If the RunLoop was spun after that
                // point, the action could attempt to be handled and an
                // we'd hit a trap when sending a sink an action in an
                // invalid state.
                //
                // 'Real world' code could hit this case as there are some
                // UI bindings that fire when a rendering/output is updated
                // that call into system API that do sometimes spin the
                // RunLoop manually (e.g. stuff calling into WebKit).
                initialRendering.sink.send(.event)
                drainMainQueueBySpinningRunLoop()
            }

        // Send an event and cause a re-render
        initialRendering.sink.send(.event)

        XCTAssertEqual(observedRenderCount, 1)

        waitForExpectations(timeout: 1)

        XCTAssertEqual(observedRenderCount, 2)
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
        typealias State = Void
        typealias Output = Never

        struct Rendering {
            var sink: Sink<Action>!
        }

        func render(state: Void, context: RenderContext<Self>) -> Rendering {
            let sink = context.makeSink(of: Action.self)
            return Rendering(sink: sink)
        }

        enum Action: WorkflowAction {
            typealias WorkflowType = ReentrancyWorkflow

            case event

            func apply(
                toState state: inout WorkflowType.State,
                context: ApplyContext<WorkflowType>
            ) -> WorkflowType.Output? {
                nil
            }
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

private func drainMainQueueBySpinningRunLoop(timeoutSeconds: UInt = 1) {
    var done = false
    DispatchQueue.main.async {
        done = true
    }

    let deadline = ContinuousClock.now + .seconds(timeoutSeconds)
    while !done, ContinuousClock.now < deadline {
        RunLoop.current.run(mode: .common, before: .now)
    }
}

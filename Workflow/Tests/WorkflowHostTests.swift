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
import Testing
import XCTest

@_spi(WorkflowRuntimeConfig)
@_spi(Experimental)
@testable import Workflow

final class WorkflowHostTests: XCTestCase {
    func test_updatedInputCausesRenderPass() {
        let host = WorkflowHost(workflow: TestWorkflow(step: .first))

        XCTAssertEqual(1, host.rendering.value)

        host.update(workflow: TestWorkflow(step: .second))

        XCTAssertEqual(2, host.rendering.value)
    }

    fileprivate struct TestWorkflow: Workflow, Equatable {
        var step: Step
        enum Step {
            case first
            case second
            case third
        }

        struct State: Equatable {}
        func makeInitialState() -> State {
            State()
        }

        typealias Rendering = Int

        func render(state: State, context: RenderContext<TestWorkflow>) -> Rendering {
            switch step {
            case .first:
                _ = TestWorkflow(step: .third)
                    .asAnyWorkflow()
                    .rendered(in: context)
                return 1
            case .second:
                _ = TestWorkflow(step: .third)
                    .asAnyWorkflow()
                    .rendered(in: context)
                return 2
            case .third:
                return 3
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
        let host = Runtime.withConfiguration { cfg in
            // Test will only pass with the 'SinkEventHandler' enabled
            cfg.useSinkEventHandler = true
        } operation: {
            WorkflowHost(workflow: ReentrancyWorkflow())
        }

        let (lifetime, token) = ReactiveSwift.Lifetime.make()
        defer { _ = token }
        let initialRendering = host.rendering.value

        var emitReentrantEvent = false

        let renderExpectation = expectation(description: "render")
        renderExpectation.expectedFulfillmentCount = 2

        host
            .rendering
            .signal
            .take(during: lifetime)
            .observeValues { val in
                defer { renderExpectation.fulfill() }
                defer { emitReentrantEvent = true }
                guard !emitReentrantEvent else { return }

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

        waitForExpectations(timeout: 1)
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

// MARK: Render Caching Tests

private struct CheapWorkflow: Workflow {
    typealias State = Void

    struct Rendering {
        var action: () -> Void
    }

    var onRender: () -> Void

    func render(state: State, context: RenderContext<Self>) -> Rendering {
        print("(cheap) render")
        onRender()
        let sink = context.makeSink(of: AnyWorkflowAction.self)
        return Rendering {
            print("(cheap) emit action")
            sink.send(.noAction)
        }
    }
}

private struct CostlyWorkflow: Workflow {
    typealias State = Void

    struct Rendering {
        var action: () -> Void
    }

    var onRender: () -> Void

    func render(state: State, context: RenderContext<Self>) -> Rendering {
        print("(costly) render")
        onRender()
        let sink = context.makeSink(of: AnyWorkflowAction.self)
        return Rendering {
            print("(costly) emit action")
            sink.send(.noAction)
        }
    }
}

struct CachesChildrenWorkflow: Workflow {
    typealias State = Void

    struct Rendering {
        var cheapAction: () -> Void
        var costlyAction: () -> Void
    }

    var onCheapRender: () -> Void
    var onExpenisveRender: () -> Void

    func render(state: State, context: RenderContext<Self>) -> Rendering {
        let cheapRendering = CheapWorkflow(onRender: onCheapRender)
            .asCacheableWorkflow()
            .rendered(in: context)

        let expensiveRendering = CostlyWorkflow(onRender: onExpenisveRender)
            .asCacheableWorkflow()
            .rendered(in: context)

        return Rendering {
            cheapRendering.action()
        } costlyAction: {
            expensiveRendering.action()
        }
    }
}

final class RenderCachingTests: XCTestCase {
    func test_renderCaching() {
        XCTAssert(Runtime.configuration.renderCachingEnabled)

        var rootRenderCount = 0
        var cheapChildRenderCount = 0
        var costlyChildRenderCount = 0

        let root = CachesChildrenWorkflow(
            onCheapRender: { cheapChildRenderCount += 1 },
            onExpenisveRender: { costlyChildRenderCount += 1 }
        )
        let host = WorkflowHost(workflow: root)

        let done = host.rendering.signal.observeValues { _ in
            rootRenderCount += 1
        }
        defer { _ = done }

        let rendering1 = host.rendering.value

        XCTAssertEqual(rootRenderCount, 0)
        XCTAssertEqual(cheapChildRenderCount, 1)
        XCTAssertEqual(costlyChildRenderCount, 1)

        // re-render cheap child
        rendering1.cheapAction()

        XCTAssertEqual(rootRenderCount, 1)
        XCTAssertEqual(cheapChildRenderCount, 2)
        XCTAssertEqual(costlyChildRenderCount, 1)

        // re-render expensive child
        rendering1.costlyAction()

        XCTAssertEqual(rootRenderCount, 2)
        XCTAssertEqual(cheapChildRenderCount, 2)
        XCTAssertEqual(costlyChildRenderCount, 2)

        // should still work
        rendering1.cheapAction()

        XCTAssertEqual(rootRenderCount, 3)
        XCTAssertEqual(cheapChildRenderCount, 3)
        XCTAssertEqual(costlyChildRenderCount, 2)
    }
}

// MARK: SinkEventHandler

@MainActor
@Suite
struct WorkflowHost_SinkEventHandlerTests {
    @Test
    func correctStateAfterInit() {
        let workflow = StateTransitioningWorkflow()
        let host = WorkflowHost(workflow: workflow)

        #expect(host.sinkEventHandler.state == .ready)
    }

    @Test
    func enqueuesEventsDuringUpdate() async throws {
        let observer = TestObserver()

        var receivedActionCount = 0
        observer.onDidReceiveAction = { _, _, _ in
            receivedActionCount += 1
        }

        let host = Runtime.withConfiguration { cfg in
            cfg.useSinkEventHandler = true
        } operation: {
            WorkflowHost(
                workflow: StateTransitioningWorkflow(),
                observers: [observer]
            )
        }

        let rendering = host.rendering.value

        let eventHandler = host.sinkEventHandler
        #expect(eventHandler.state == .ready)

        var handlerStatesDuringUpdate: [SinkEventHandler.State] = []
        observer.onDidChange = { _, _, _, _ in
            handlerStatesDuringUpdate.append(eventHandler.state)
        }

        var handlerStatesDuringRender: [SinkEventHandler.State] = []
        var emitOnce: (() -> Void)? = { rendering.toggle() }
        observer.onWillRender = { _, _, _ in
            handlerStatesDuringRender.append(eventHandler.state)
            if let emit = emitOnce.take() {
                // emit an event once – we expect it to be enqueued
                emit()
            }
            return nil
        }

        host.update(workflow: StateTransitioningWorkflow())

        #expect(handlerStatesDuringUpdate == [.busy])
        #expect(handlerStatesDuringRender == [.busy])

        // reentrant event should have been sent & queued
        #expect(emitOnce == nil)
        #expect(receivedActionCount == 0)

        await drainMainQueue()

        // reentrant event should have been handled
        #expect(receivedActionCount == 1)
    }

    @Test
    func enqueuesEventsDuringEventHandling() async throws {
        let observer = TestObserver()

        let host = Runtime.withConfiguration { cfg in
            cfg.useSinkEventHandler = true
        } operation: {
            WorkflowHost(
                workflow: StateTransitioningWorkflow(),
                observers: [observer]
            )
        }

        let rendering = host.rendering.value
        let eventHandler = host.sinkEventHandler

        var didEmit = false
        let emitActionOnce = {
            var emitToggle: (() -> Void)? = { rendering.toggle() }
            return {
                guard let emit = emitToggle.take() else { return }
                didEmit = true
                emit()
            }
        }()

        var receivedActionCount = 0
        var handlerStatesOnExternalAction: [SinkEventHandler.State] = []
        observer.onDidReceiveAction = { _, _, _ in
            receivedActionCount += 1
            handlerStatesOnExternalAction.append(eventHandler.state)
        }

        // emit a reentrant action during action
        observer.onApplyAction = { _, _, _, _ in
            emitActionOnce()
            return nil
        }

        #expect(eventHandler.state == .ready)

        // emit a 'normal' event, which the observer will
        // see and emit a second one
        rendering.toggle()

        #expect(didEmit == true)
        #expect(receivedActionCount == 1) // only the first processed so far
        #expect(handlerStatesOnExternalAction == [.busy])

        await drainMainQueue()

        // reentrant event should have been handled
        #expect(receivedActionCount == 2)
        #expect(handlerStatesOnExternalAction == [.busy, .busy])
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

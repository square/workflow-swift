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
}

// MARK: Utility Types

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

            func apply(toState state: inout Parent.State) -> Never? {
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

            func apply(toState state: inout Void) -> Child.Output? {
                .eventOccurred
            }
        }
    }
}

// MARK: Short Circuit Tests

extension WorkflowHostTests {
    func test_shortCircuitOutputPropagation() {
        typealias ParentWorkflow = ShortCircuitTesting.ParentWorkflow
        typealias ChildWorkflow = ShortCircuitTesting.ChildWorkflow

        let parent = ParentWorkflow()
        let host = WorkflowHost(workflow: parent)

        let root = host.rootNode
        let originalHandler = host.rootNode.onOutput

        // intercept the root node's output handler to
        // track how many times it's called
        var rootNodeOutputCount = 0
        root.onOutput = {
            rootNodeOutputCount += 1
            originalHandler?($0)
        }

        let rendering = host.rendering.value

        var receivedOutput: ParentWorkflow.Output?
        let disposable = host.output.signal.observeValues { output in
            receivedOutput = output
        }
        defer { disposable?.dispose() }

        XCTAssertEqual(rootNodeOutputCount, 0)

        for _ in 1 ... 3 {
            // Trigger the child workflow's output a few times
            rendering.sendChildAction(.propagatingEvent("hello"))
            XCTAssertEqual(receivedOutput, .propagatingEvent("hello"))
        }

        // Each action should increment the root output count since it
        // should not short-circuit
        XCTAssertEqual(rootNodeOutputCount, 3)

        // If the child produces no output, it should skip to the host
        rendering.sendChildAction(.ignoredEvent)

        // Should skip the parent application, hence also the root node's
        // `onOutput` callback.
        XCTAssertEqual(rootNodeOutputCount, 3)
    }
}

// MARK: -

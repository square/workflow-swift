/*
 * Copyright 2025 Square Inc.
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

@_spi(WorkflowRuntimeConfig)
@testable import Workflow

final class RenderOnlyIfStateChangedEnabledTests: XCTestCase {
    override func invokeTest() {
        Runtime.withConfiguration { cfg in
            cfg.renderOnlyIfStateChanged = true
        } operation: {
            super.invokeTest()
        }
    }

    func test_skipsRenderWhenNoStateChangeAndRenderOnlyIfStateChangedEnabled() {
        let host = WorkflowHost(workflow: CounterWorkflow())

        var renderCount = 0
        let cancellable = host.rendering.dropFirst().sink(receiveValue: { _ in renderCount += 1 })
        defer { cancellable.cancel() }

        XCTAssertEqual(renderCount, 0)
        XCTAssertEqual(host.rendering.value.count, 0)

        host.rendering.value.noOpAction()

        XCTAssertEqual(renderCount, 0)
        XCTAssertEqual(host.rendering.value.count, 0)
    }

    func test_reRendersWhenNoStateChangeAndRenderOnlyIfStateChangedDisabled() {
        withRenderOnlyIfStateChangedDisabled {
            let host = WorkflowHost(workflow: CounterWorkflow())

            var renderCount = 0
            let cancellable = host.rendering.dropFirst().sink(receiveValue: { _ in renderCount += 1 })
            defer { cancellable.cancel() }

            XCTAssertEqual(renderCount, 0)
            XCTAssertEqual(host.rendering.value.count, 0)

            host.rendering.value.noOpAction()

            XCTAssertEqual(renderCount, 1)
            XCTAssertEqual(host.rendering.value.count, 0)
        }
    }

    func test_rendersWhenStateChangesAndRenderOnlyIfStateChangedEnabled() {
        let host = WorkflowHost(workflow: CounterWorkflow())

        var renderCount = 0
        let cancellable = host.rendering.dropFirst().sink(receiveValue: { _ in renderCount += 1 })
        defer { cancellable.cancel() }

        XCTAssertEqual(renderCount, 0)
        XCTAssertEqual(host.rendering.value.count, 0)

        host.rendering.value.incrementAction()

        XCTAssertEqual(renderCount, 1)
        XCTAssertEqual(host.rendering.value.count, 1)
    }

    func test_skipsRenderWithVoidStateAndPropertyAccess() {
        let host = WorkflowHost(workflow: VoidStateWorkflow(prop: 42))

        var renderCount = 0
        var outputs: [Int] = []

        let cancellable = host.rendering.dropFirst().sink(receiveValue: { _ in renderCount += 1 })
        defer { cancellable.cancel() }

        let outputCancellable = host.outputPublisher.sink(receiveValue: { outputs.append($0) })
        defer { outputCancellable.cancel() }

        XCTAssertEqual(renderCount, 0)
        XCTAssertEqual(outputs, [])

        host.rendering.value.action()

        XCTAssertEqual(renderCount, 0)
        XCTAssertEqual(outputs, [42])
    }

    func test_rendersWhenSubtreeInvalidatedRegardlessOfStateChange() {
        let host = WorkflowHost(workflow: ParentWorkflow())

        var renderCount = 0
        let cancellable = host.rendering.dropFirst().sink(receiveValue: { _ in renderCount += 1 })
        defer { cancellable.cancel() }

        XCTAssertEqual(renderCount, 0)

        host.rendering.value.childAction()

        XCTAssertEqual(renderCount, 1)
    }

    func test_externalUpdateAlwaysRendersDueToSubtreeInvalidation() {
        let host = WorkflowHost(workflow: CounterWorkflow())

        var renderCount = 0
        let cancellable = host.rendering.dropFirst().sink(receiveValue: { _ in renderCount += 1 })
        defer { cancellable.cancel() }

        XCTAssertEqual(renderCount, 0)

        host.update(workflow: CounterWorkflow())

        XCTAssertEqual(renderCount, 1)
    }

    func test_outputEventsEmittedEvenWhenRenderSkipped() {
        let host = WorkflowHost(workflow: OutputWorkflow())

        var renderCount = 0
        var outputCount = 0

        let cancellable = host.rendering.dropFirst().sink(receiveValue: { _ in renderCount += 1 })
        defer { cancellable.cancel() }

        let outputCancellable = host.outputPublisher.sink(receiveValue: { _ in outputCount += 1 })
        defer { outputCancellable.cancel() }

        XCTAssertEqual(renderCount, 0)
        XCTAssertEqual(outputCount, 0)

        host.rendering.value.emitOutputAction()

        XCTAssertEqual(renderCount, 0)
        XCTAssertEqual(outputCount, 1)
    }

    func test_eventPipesWorkWhenRenderSkipped() {
        let host = WorkflowHost(workflow: CounterWorkflow())
        let initialRendering = host.rendering.value

        var renderCount = 0
        var outputCount = 0

        let cancellable = host.rendering.dropFirst().sink(receiveValue: { _ in renderCount += 1 })
        let outputCancellable = host.outputPublisher.sink(receiveValue: { _ in outputCount += 1 })

        defer {
            cancellable.cancel()
            outputCancellable.cancel()
        }

        XCTAssertEqual(outputCount, 0)
        XCTAssertEqual(renderCount, 0)

        initialRendering.noOpAction()

        XCTAssertEqual(outputCount, 1)
        XCTAssertEqual(renderCount, 0)

        initialRendering.incrementAction()

        XCTAssertEqual(outputCount, 2)
        XCTAssertEqual(renderCount, 1)
    }

    func test_eventPipesWorkWhenRenderNotSkipped() {
        let host = WorkflowHost(workflow: CounterWorkflow())
        let initialRendering = host.rendering.value

        var renderCount = 0
        var outputCount = 0

        let cancellable = host.rendering.dropFirst().sink(receiveValue: { _ in renderCount += 1 })
        let outputCancellable = host.outputPublisher.sink(receiveValue: { _ in outputCount += 1 })

        defer {
            cancellable.cancel()
            outputCancellable.cancel()
        }

        XCTAssertEqual(outputCount, 0)
        XCTAssertEqual(renderCount, 0)

        initialRendering.incrementAction()

        XCTAssertEqual(outputCount, 1)
        XCTAssertEqual(renderCount, 1)

        initialRendering.noOpAction()

        XCTAssertEqual(outputCount, 2)
        XCTAssertEqual(renderCount, 1)
    }
}

private func withRenderOnlyIfStateChangedDisabled(
    _ perform: () -> Void
) {
    Runtime.withConfiguration(override: { cfg in
        cfg.renderOnlyIfStateChanged = false
    }, operation: perform)
}

// MARK: - Test Workflows

extension RenderOnlyIfStateChangedEnabledTests {
    fileprivate struct CounterWorkflow: Workflow {
        struct State: Equatable {
            var count = 0
        }

        struct Rendering {
            let count: Int
            let incrementAction: () -> Void
            let noOpAction: () -> Void
        }

        typealias Output = Void

        func makeInitialState() -> State {
            State()
        }

        func render(state: State, context: RenderContext<CounterWorkflow>) -> Rendering {
            let incrementSink = context.makeSink(of: IncrementAction.self)
            let noOpSink = context.makeSink(of: NoOpAction.self)

            return Rendering(
                count: state.count,
                incrementAction: { incrementSink.send(.increment) },
                noOpAction: { noOpSink.send(.noOp) }
            )
        }

        enum IncrementAction: WorkflowAction {
            case increment

            func apply(
                toState state: inout CounterWorkflow.State,
                context: ApplyContext<CounterWorkflow>
            ) -> Output? {
                state.count += 1
                return ()
            }
        }

        enum NoOpAction: WorkflowAction {
            case noOp

            func apply(
                toState state: inout CounterWorkflow.State,
                context: ApplyContext<CounterWorkflow>
            ) -> Output? {
                // Don't change state
                ()
            }
        }
    }

    fileprivate struct OutputWorkflow: Workflow {
        struct State: Equatable {}

        func makeInitialState() -> State {
            State()
        }

        enum Output {
            case emitted
        }

        struct Rendering {
            let emitOutputAction: () -> Void
        }

        func render(state: State, context: RenderContext<OutputWorkflow>) -> Rendering {
            let sink = context.makeSink(of: EmitOutputAction.self)

            return Rendering(
                emitOutputAction: { sink.send(.emit) }
            )
        }

        enum EmitOutputAction: WorkflowAction {
            case emit

            func apply(
                toState state: inout OutputWorkflow.State,
                context: ApplyContext<OutputWorkflow>
            ) -> OutputWorkflow.Output? {
                // Don't change state but emit output
                .emitted
            }
        }
    }

    fileprivate struct ParentWorkflow: Workflow {
        struct State: Equatable {}

        func makeInitialState() -> State {
            State()
        }

        struct Rendering {
            let childAction: () -> Void
        }

        func render(state: State, context: RenderContext<ParentWorkflow>) -> Rendering {
            let childRendering = ChildWorkflow()
                .mapOutput { _ in ParentAction.childUpdated }
                .rendered(in: context)

            return Rendering(
                childAction: childRendering.action
            )
        }

        enum ParentAction: WorkflowAction {
            case childUpdated

            func apply(
                toState state: inout ParentWorkflow.State,
                context: ApplyContext<ParentWorkflow>
            ) -> Never? {
                // Don't change state
                nil
            }
        }
    }

    fileprivate struct ChildWorkflow: Workflow {
        struct State {
            var value = 0
        }

        func makeInitialState() -> State {
            State()
        }

        enum Output {
            case updated
        }

        struct Rendering {
            let action: () -> Void
        }

        func render(state: State, context: RenderContext<ChildWorkflow>) -> Rendering {
            let sink = context.makeSink(of: UpdateAction.self)

            return Rendering(
                action: { sink.send(.update) }
            )
        }

        enum UpdateAction: WorkflowAction {
            case update

            func apply(
                toState state: inout ChildWorkflow.State,
                context: ApplyContext<ChildWorkflow>
            ) -> ChildWorkflow.Output? {
                state.value += 1
                return .updated
            }
        }
    }

    fileprivate struct VoidStateWorkflow: Workflow {
        typealias State = Void

        struct Rendering {
            let action: () -> Void
        }

        typealias Output = Int

        var prop: Int

        func makeInitialState() -> State {
            State()
        }

        func render(state: State, context: RenderContext<Self>) -> Rendering {
            let readPropSink = context.makeSink(of: ReadPropAction.self)

            return Rendering(
                action: { readPropSink.send(.readProp) }
            )
        }

        enum ReadPropAction: WorkflowAction {
            case readProp

            func apply(
                toState state: inout State,
                context: ApplyContext<VoidStateWorkflow>
            ) -> Output? {
                context[workflowValue: \.prop]
            }
        }
    }
}

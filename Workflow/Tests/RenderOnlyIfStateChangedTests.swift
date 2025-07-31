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
import Testing

@_spi(WorkflowRuntimeConfig)
@testable
import Workflow

@Suite(renderOnlyIfStateChanged)
@MainActor
struct RenderOnlyIfStateChangedEnabledTests {
    // MARK: - Render Skipping Tests

    @Test
    func skipsRenderWhenNoStateChangeAndRenderOnlyIfStateChangedEnabled() {
        let host = WorkflowHost(workflow: CounterWorkflow())

        var renderCount = 0
        let disposable = host.rendering.signal.observeValues { _ in
            renderCount += 1
        }
        defer { disposable?.dispose() }

        // Initial render
        #expect(renderCount == 0)
        #expect(host.rendering.value.count == 0)

        // Trigger action that doesn't change state
        host.rendering.value.noOpAction()

        // Should not render since state didn't change
        #expect(renderCount == 0)
        #expect(host.rendering.value.count == 0)
    }

    @Test(renderOnlyIfStateChangedDisabled)
    func reRendersWhenNoStateChangeAndRenderOnlyIfStateChangedDisabled() {
        let host = WorkflowHost(workflow: CounterWorkflow())

        var renderCount = 0
        let disposable = host.rendering.signal.observeValues { _ in
            renderCount += 1
        }
        defer { disposable?.dispose() }

        // Initial render
        #expect(renderCount == 0)
        #expect(host.rendering.value.count == 0)

        // Trigger action that doesn't change state
        host.rendering.value.noOpAction()

        // Should render again since the skipping config is off
        #expect(renderCount == 1)
        #expect(host.rendering.value.count == 0)
    }

    @Test
    func rendersWhenStateChangesAndRenderOnlyIfStateChangedEnabled() {
        let host = WorkflowHost(workflow: CounterWorkflow())

        var renderCount = 0
        let disposable = host.rendering.signal.observeValues { _ in
            renderCount += 1
        }
        defer { disposable?.dispose() }

        // Initial render
        #expect(renderCount == 0)
        #expect(host.rendering.value.count == 0)

        // Trigger action that changes state
        host.rendering.value.incrementAction()

        // Should render since state changed
        #expect(renderCount == 1)
        #expect(host.rendering.value.count == 1)
    }

    @Test
    func skipsRenderWithVoidStateAndPropertyAccess() {
        let host = WorkflowHost(workflow: VoidStateWorkflow(prop: 42))

        var renderCount = 0
        var outputs: [Int] = []

        let renderDisposable = host.rendering.signal.observeValues { _ in
            renderCount += 1
        }
        defer { renderDisposable?.dispose() }

        let outputDisposable = host.output.observeValues {
            outputs.append($0)
        }
        defer { outputDisposable?.dispose() }

        // Initial render
        #expect(renderCount == 0)
        #expect(outputs == [])

        // Trigger action that reads from props (state is Void)
        host.rendering.value.action()

        // Should not render since the State is Void
        #expect(renderCount == 0)
        #expect(outputs == [42])
    }

    // MARK: - Subtree Invalidation Tests

    @Test
    func rendersWhenSubtreeInvalidatedRegardlessOfStateChange() {
        let host = WorkflowHost(workflow: ParentWorkflow())

        var renderCount = 0
        let disposable = host.rendering.signal.observeValues { _ in
            renderCount += 1
        }
        defer { disposable?.dispose() }

        // Initial render
        #expect(renderCount == 0)

        // Trigger child action that invalidates subtree
        host.rendering.value.childAction()

        // Should render due to subtree invalidation even if parent state doesn't change
        #expect(renderCount == 1)
    }

    // MARK: - External Update Tests

    @Test
    func externalUpdateAlwaysRendersDueToSubtreeInvalidation() {
        let host = WorkflowHost(workflow: CounterWorkflow())

        var renderCount = 0
        let disposable = host.rendering.signal.observeValues { _ in
            renderCount += 1
        }
        defer { disposable?.dispose() }

        // Initial render
        #expect(renderCount == 0)

        // External update (always marks subtree as invalidated)
        host.update(workflow: CounterWorkflow())

        // Should render due to external update marking subtree as invalidated
        #expect(renderCount == 1)
    }

    // MARK: - Output Event Tests

    @Test
    func outputEventsEmittedEvenWhenRenderSkipped() {
        let host = WorkflowHost(workflow: OutputWorkflow())

        var renderCount = 0
        var outputCount = 0

        let renderDisposable = host.rendering.signal.observeValues { _ in
            renderCount += 1
        }
        defer { renderDisposable?.dispose() }

        let outputDisposable = host.output.observeValues { _ in
            outputCount += 1
        }
        defer { outputDisposable?.dispose() }

        // Initial render
        #expect(renderCount == 0)
        #expect(outputCount == 0)

        // Trigger action that emits output but doesn't change state
        host.rendering.value.emitOutputAction()

        // Should not render but should emit output
        #expect(renderCount == 0)
        #expect(outputCount == 1)
    }

    // MARK: - Event Pipes

    @Test
    func eventPipesWorkWhenRenderSkipped() {
        let host = WorkflowHost(workflow: CounterWorkflow())

        // Track the initial rendering reference
        let initialRendering = host.rendering.value

        var outputCount = 0
        let outputDisposable = host.output.observeValues { _ in
            outputCount += 1
        }
        var renderCount = 0
        let renderDisposable = host.rendering.signal.observeValues { _ in
            renderCount += 1
        }
        defer {
            outputDisposable?.dispose()
            renderDisposable?.dispose()
        }

        #expect(outputCount == 0)
        #expect(renderCount == 0)

        // Trigger action that doesn't change state
        initialRendering.noOpAction()

        #expect(outputCount == 1)
        #expect(renderCount == 0)

        // The event pipes should have been left alone (not invalidated), so
        // emitting another event still works.
        initialRendering.incrementAction()

        #expect(outputCount == 2)
        #expect(renderCount == 1)
    }

    @Test
    func eventPipesWorkWhenRenderNotSkipped() {
        let host = WorkflowHost(workflow: CounterWorkflow())

        // Track the initial rendering reference
        let initialRendering = host.rendering.value

        var outputCount = 0
        let outputDisposable = host.output.observeValues { _ in
            outputCount += 1
        }
        var renderCount = 0
        let renderDisposable = host.rendering.signal.observeValues { _ in
            renderCount += 1
        }
        defer {
            outputDisposable?.dispose()
            renderDisposable?.dispose()
        }

        #expect(outputCount == 0)
        #expect(renderCount == 0)

        // Trigger action that causes a re-render
        initialRendering.incrementAction()

        #expect(outputCount == 1)
        #expect(renderCount == 1)

        // The event pipes should have been re-enabled, so
        // emitting another event still works. If we forgot
        // to do so, the runtime should trap.
        initialRendering.noOpAction()

        #expect(outputCount == 2)
        #expect(renderCount == 1)
    }
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

// MARK: - Traits

private struct RenderOnlyIfStateChangedTrait: SuiteTrait, TestTrait {
    var enabled = true

    struct TestScopeProvider: TestScoping {
        var enabled: Bool

        func provideScope(
            for test: Test,
            testCase: Test.Case?,
            performing function: @Sendable () async throws -> Void
        ) async throws {
            var config = Runtime.configuration
            config.renderOnlyIfStateChanged = enabled

            try await Runtime.$_currentConfiguration.withValue(config, operation: function)
        }
    }

    func scopeProvider(for test: Test, testCase: Test.Case?) -> TestScopeProvider? {
        TestScopeProvider(enabled: enabled)
    }
}

private var renderOnlyIfStateChanged: some SuiteTrait & TestTrait {
    RenderOnlyIfStateChangedTrait()
}

private var renderOnlyIfStateChangedDisabled: some SuiteTrait & TestTrait {
    RenderOnlyIfStateChangedTrait(enabled: false)
}

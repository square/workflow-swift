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
@_spi(WorkflowRuntimeConfig) @testable import Workflow

final class RenderOnlyIfStateChangedTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Reset runtime config before each test
        Runtime.resetConfig()
    }

    // MARK: - Basic Functionality Tests

    func test_renderOnlyIfStateChanged_disabled_by_default() {
        let workflow = CounterWorkflow()
        let host = WorkflowHost(workflow: workflow)

        XCTAssertFalse(host.context.runtimeConfig.renderOnlyIfStateChanged)
    }

//    func test_renderOnlyIfStateChanged_enabled_via_bootstrap() {
//        Runtime.bootstrap { config in
//            config.renderOnlyIfStateChanged = true
//        }
//
//        let workflow = CounterWorkflow()
//        let host = WorkflowHost(workflow: workflow)
//
//        XCTAssertTrue(host.context.runtimeConfig.renderOnlyIfStateChanged)
//    }
//
//    func test_renderOnlyIfStateChanged_with_task_local_override() {
//        var customConfig = Runtime.configuration
//        customConfig.renderOnlyIfStateChanged = true
//
//        let workflow = CounterWorkflow()
//        let host = Runtime.$_currentConfiguration.withValue(customConfig) {
//            WorkflowHost(workflow: workflow)
//        }
//
//        XCTAssertTrue(host.context.runtimeConfig.renderOnlyIfStateChanged)
//    }
//
//    // MARK: - Render Skipping Tests
//
//    func test_renders_always_when_renderOnlyIfStateChanged_disabled() {
//        let workflow = CounterWorkflow()
//        let host = WorkflowHost(workflow: workflow)
//        var renderCount = 0
//
//        let disposable = host.rendering.signal.observeValues { _ in
//            renderCount += 1
//        }
//        defer { disposable?.dispose() }
//
//        // Initial render
//        XCTAssertEqual(renderCount, 1)
//        XCTAssertEqual(host.rendering.value, 0)
//
//        // Trigger action that doesn't change state
//        host.rendering.value.noOpAction()
//
//        // Should still render even though state didn't change
//        XCTAssertEqual(renderCount, 2)
//        XCTAssertEqual(host.rendering.value, 0)
//    }
//
//    func test_skips_render_when_no_state_change_and_renderOnlyIfStateChanged_enabled() {
//        var customConfig = Runtime.configuration
//        customConfig.renderOnlyIfStateChanged = true
//
//        let workflow = CounterWorkflow()
//        let host = Runtime.$_currentConfiguration.withValue(customConfig) {
//            WorkflowHost(workflow: workflow)
//        }
//
//        var renderCount = 0
//        let disposable = host.rendering.signal.observeValues { _ in
//            renderCount += 1
//        }
//        defer { disposable?.dispose() }
//
//        // Initial render
//        XCTAssertEqual(renderCount, 1)
//        XCTAssertEqual(host.rendering.value, 0)
//
//        // Trigger action that doesn't change state
//        host.rendering.value.noOpAction()
//
//        // Should not render since state didn't change
//        XCTAssertEqual(renderCount, 1)
//        XCTAssertEqual(host.rendering.value, 0)
//    }
//
//    func test_renders_when_state_changes_and_renderOnlyIfStateChanged_enabled() {
//        var customConfig = Runtime.configuration
//        customConfig.renderOnlyIfStateChanged = true
//
//        let workflow = CounterWorkflow()
//        let host = Runtime.$_currentConfiguration.withValue(customConfig) {
//            WorkflowHost(workflow: workflow)
//        }
//
//        var renderCount = 0
//        let disposable = host.rendering.signal.observeValues { _ in
//            renderCount += 1
//        }
//        defer { disposable?.dispose() }
//
//        // Initial render
//        XCTAssertEqual(renderCount, 1)
//        XCTAssertEqual(host.rendering.value, 0)
//
//        // Trigger action that changes state
//        host.rendering.value.incrementAction()
//
//        // Should render since state changed
//        XCTAssertEqual(renderCount, 2)
//        XCTAssertEqual(host.rendering.value, 1)
//    }
//
//    // MARK: - Subtree Invalidation Tests
//
//    func test_renders_when_subtree_invalidated_regardless_of_state_change() {
//        var customConfig = Runtime.configuration
//        customConfig.renderOnlyIfStateChanged = true
//
//        let workflow = ParentWorkflow()
//        let host = Runtime.$_currentConfiguration.withValue(customConfig) {
//            WorkflowHost(workflow: workflow)
//        }
//
//        var renderCount = 0
//        let disposable = host.rendering.signal.observeValues { _ in
//            renderCount += 1
//        }
//        defer { disposable?.dispose() }
//
//        // Initial render
//        XCTAssertEqual(renderCount, 1)
//
//        // Trigger child action that invalidates subtree
//        host.rendering.value.childAction()
//
//        // Should render due to subtree invalidation even if parent state doesn't change
//        XCTAssertEqual(renderCount, 2)
//    }
//
//    // MARK: - External Update Tests
//
//    func test_external_update_always_renders_due_to_subtree_invalidation() {
//        var customConfig = Runtime.configuration
//        customConfig.renderOnlyIfStateChanged = true
//
//        let workflow = CounterWorkflow()
//        let host = Runtime.$_currentConfiguration.withValue(customConfig) {
//            WorkflowHost(workflow: workflow)
//        }
//
//        var renderCount = 0
//        let disposable = host.rendering.signal.observeValues { _ in
//            renderCount += 1
//        }
//        defer { disposable?.dispose() }
//
//        // Initial render
//        XCTAssertEqual(renderCount, 1)
//
//        // External update (always marks subtree as invalidated)
//        host.update(workflow: CounterWorkflow())
//
//        // Should render due to external update marking subtree as invalidated
//        XCTAssertEqual(renderCount, 2)
//    }
//
//    // MARK: - Output Event Tests
//
//    func test_output_events_emitted_even_when_render_skipped() {
//        var customConfig = Runtime.configuration
//        customConfig.renderOnlyIfStateChanged = true
//
//        let workflow = OutputWorkflow()
//        let host = Runtime.$_currentConfiguration.withValue(customConfig) {
//            WorkflowHost(workflow: workflow)
//        }
//
//        var renderCount = 0
//        var outputCount = 0
//
//        let renderDisposable = host.rendering.signal.observeValues { _ in
//            renderCount += 1
//        }
//        defer { renderDisposable?.dispose() }
//
//        let outputDisposable = host.output.observeValues { _ in
//            outputCount += 1
//        }
//        defer { outputDisposable?.dispose() }
//
//        // Initial render
//        XCTAssertEqual(renderCount, 1)
//        XCTAssertEqual(outputCount, 0)
//
//        // Trigger action that emits output but doesn't change state
//        host.rendering.value.emitOutputAction()
//
//        // Should not render but should emit output
//        XCTAssertEqual(renderCount, 1)
//        XCTAssertEqual(outputCount, 1)
//    }
//
//    // MARK: - Event Pipe Re-enabling Tests
//
//    func test_event_pipes_not_re_enabled_when_render_skipped() {
//        let workflow = CounterWorkflow()
//        let host = Runtime.withConfiguration { config in
//            config.renderOnlyIfStateChanged = true
//        } operation: {
//            WorkflowHost(workflow: workflow)
//        }
//
//        // Track the initial rendering reference
//        let initialRendering = host.rendering.value
//
//        // Trigger action that doesn't change state
//        initialRendering.noOpAction()
//
//        // The rendering reference should be the same since no render occurred
//        XCTAssertTrue(host.rendering.value === initialRendering)
//    }
//
//    func test_event_pipes_re_enabled_when_render_occurs() {
//        var customConfig = Runtime.configuration
//        customConfig.renderOnlyIfStateChanged = true
//
//        let workflow = CounterWorkflow()
//        let host = Runtime.$_currentConfiguration.withValue(customConfig) {
//            WorkflowHost(workflow: workflow)
//        }
//
//        // Track the initial rendering reference
//        let initialRendering = host.rendering.value
//
//        // Trigger action that changes state
//        initialRendering.incrementAction()
//
//        // The rendering reference should be different since a render occurred
//        XCTAssertFalse(host.rendering.value === initialRendering)
//    }
}

// MARK: - Test Workflows

extension RenderOnlyIfStateChangedTests {
    fileprivate struct CounterWorkflow: Workflow {
        struct State {
            var count = 0
        }

        func makeInitialState() -> State {
            State()
        }

        struct Rendering {
            let count: Int
            let incrementAction: () -> Void
            let noOpAction: () -> Void
        }

        func render(state: State, context: RenderContext<CounterWorkflow>) -> Rendering {
            let incrementSink = context.makeSink(of: IncrementAction.self)
            let noOpSink = context.makeSink(of: NoOpAction.self)

            return Rendering(
                count: state.count,
                incrementAction: { incrementSink.send(IncrementAction()) },
                noOpAction: { noOpSink.send(NoOpAction()) }
            )
        }

        enum IncrementAction: WorkflowAction {
            case increment

            init() { self = .increment }

            func apply(toState state: inout CounterWorkflow.State, context: ApplyContext<CounterWorkflow>) -> Never? {
                state.count += 1
                return nil
            }
        }

        enum NoOpAction: WorkflowAction {
            case noOp

            init() { self = .noOp }

            func apply(toState state: inout CounterWorkflow.State, context: ApplyContext<CounterWorkflow>) -> Never? {
                // Don't change state
                nil
            }
        }
    }

    fileprivate struct OutputWorkflow: Workflow {
        struct State {}

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
                emitOutputAction: { sink.send(EmitOutputAction()) }
            )
        }

        enum EmitOutputAction: WorkflowAction {
            case emit

            init() { self = .emit }

            func apply(toState state: inout OutputWorkflow.State, context: ApplyContext<OutputWorkflow>) -> OutputWorkflow.Output? {
                // Don't change state but emit output
                .emitted
            }
        }
    }

    fileprivate struct ParentWorkflow: Workflow {
        struct State {}

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

            func apply(toState state: inout ParentWorkflow.State, context: ApplyContext<ParentWorkflow>) -> Never? {
                // Don't change parent state
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
                action: { sink.send(UpdateAction()) }
            )
        }

        enum UpdateAction: WorkflowAction {
            case update

            init() { self = .update }

            func apply(toState state: inout ChildWorkflow.State, context: ApplyContext<ChildWorkflow>) -> ChildWorkflow.Output? {
                state.value += 1
                return .updated
            }
        }
    }
}

// MARK: - Utility Extensions

extension RenderOnlyIfStateChangedTests.CounterWorkflow.Rendering: Equatable {
    fileprivate static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.count == rhs.count
    }
}

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
@testable import Workflow

final class SubtreeManagerTests: XCTestCase {
    func test_maintainsChildrenBetweenRenderPasses() {
        let manager = WorkflowNode<ParentWorkflow>.SubtreeManager()
        XCTAssertTrue(manager.childWorkflows.isEmpty)

        _ = manager.render { context -> TestViewModel in
            context.render(
                workflow: TestWorkflow(),
                key: "",
                outputMap: { _ in AnyWorkflowAction.noAction }
            )
        }

        XCTAssertEqual(manager.childWorkflows.count, 1)
        let child = manager.childWorkflows.values.first!

        _ = manager.render { context -> TestViewModel in
            context.render(
                workflow: TestWorkflow(),
                key: "",
                outputMap: { _ in AnyWorkflowAction.noAction }
            )
        }

        XCTAssertEqual(manager.childWorkflows.count, 1)
        XCTAssertTrue(manager.childWorkflows.values.first === child)
    }

    func test_removesUnusedChildrenAfterRenderPasses() {
        let manager = WorkflowNode<ParentWorkflow>.SubtreeManager()
        _ = manager.render { context -> TestViewModel in
            context.render(
                workflow: TestWorkflow(),
                key: "",
                outputMap: { _ in AnyWorkflowAction.noAction }
            )
        }

        XCTAssertEqual(manager.childWorkflows.count, 1)

        manager.render { context -> Void in
        }

        XCTAssertTrue(manager.childWorkflows.isEmpty)
    }

    func test_emitsChildEvents() {
        let manager = WorkflowNode<ParentWorkflow>.SubtreeManager()

        var events: [AnyWorkflowAction<ParentWorkflow>] = []

        manager.onUpdate = {
            switch $0 {
            case .update(let event, _):
                events.append(AnyWorkflowAction(event))
            default:
                break
            }
        }

        let viewModel = manager.render { context -> TestViewModel in
            context.render(
                workflow: TestWorkflow(),
                key: "",
                outputMap: { _ in AnyWorkflowAction.noAction }
            )
        }
        manager.enableEvents()

        viewModel.onTap()
        viewModel.onTap()

        RunLoop.current.run(until: Date().addingTimeInterval(0.1))

        XCTAssertEqual(events.count, 2)
    }

    func test_emitsChangeEvents() {
        let manager = WorkflowNode<ParentWorkflow>.SubtreeManager()

        var changeCount = 0

        manager.onUpdate = { _ in
            changeCount += 1
        }

        let viewModel = manager.render { context -> TestViewModel in
            context.render(
                workflow: TestWorkflow(),
                key: "",
                outputMap: { _ in AnyWorkflowAction.noAction }
            )
        }
        manager.enableEvents()

        viewModel.onToggle()
        viewModel.onToggle()

        RunLoop.current.run(until: Date().addingTimeInterval(0.1))

        XCTAssertEqual(changeCount, 2)
    }

    func test_invalidatesContextAfterRender() {
        let manager = WorkflowNode<ParentWorkflow>.SubtreeManager()

        var escapingContext: RenderContext<ParentWorkflow>!

        _ = manager.render { context -> TestViewModel in
            XCTAssertTrue(context.isValid)
            escapingContext = context
            return context.render(
                workflow: TestWorkflow(),
                key: "",
                outputMap: { _ in AnyWorkflowAction.noAction }
            )
        }
        manager.enableEvents()

        XCTAssertFalse(escapingContext.isValid)
    }

    // MARK: - SideEffect

    func test_maintainsSideEffectLifetimeBetweenRenderPasses() {
        let manager = WorkflowNode<ParentWorkflow>.SubtreeManager()
        XCTAssertTrue(manager.sideEffectLifetimes.isEmpty)

        _ = manager.render { context -> TestViewModel in
            context.runSideEffect(key: "helloWorld") { _ in }
            return context.render(
                workflow: TestWorkflow(),
                key: "",
                outputMap: { _ in AnyWorkflowAction.noAction }
            )
        }

        XCTAssertEqual(manager.sideEffectLifetimes.count, 1)
        let sideEffectKey = manager.sideEffectLifetimes.values.first!

        _ = manager.render { context -> TestViewModel in
            context.runSideEffect(key: "helloWorld") { _ in
                XCTFail("Unexpected SideEffect execution")
            }
            return context.render(
                workflow: TestWorkflow(),
                key: "",
                outputMap: { _ in AnyWorkflowAction.noAction }
            )
        }

        XCTAssertEqual(manager.sideEffectLifetimes.count, 1)
        XCTAssertTrue(manager.sideEffectLifetimes.values.first === sideEffectKey)
    }

    func test_endsUnusedSideEffectLifetimeAfterRenderPasses() {
        let manager = WorkflowNode<ParentWorkflow>.SubtreeManager()
        XCTAssertTrue(manager.sideEffectLifetimes.isEmpty)

        let lifetimeEndedExpectation = expectation(description: "Lifetime Ended Expectations")
        _ = manager.render { context -> TestViewModel in
            context.runSideEffect(key: "helloWorld") { lifetime in
                lifetime.onEnded {
                    // Capturing `lifetime` to make sure a retain-cycle will still trigger the `onEnded` block
                    print("\(lifetime)")
                    lifetimeEndedExpectation.fulfill()
                }
            }
            return context.render(
                workflow: TestWorkflow(),
                key: "",
                outputMap: { _ in AnyWorkflowAction.noAction }
            )
        }

        XCTAssertEqual(manager.sideEffectLifetimes.count, 1)

        _ = manager.render { context -> TestViewModel in
            context.render(
                workflow: TestWorkflow(),
                key: "",
                outputMap: { _ in AnyWorkflowAction.noAction }
            )
        }

        XCTAssertEqual(manager.sideEffectLifetimes.count, 0)
        wait(for: [lifetimeEndedExpectation], timeout: 1)
    }

    func test_verifySideEffectsWithDifferentKeysAreExecuted() {
        let manager = WorkflowNode<ParentWorkflow>.SubtreeManager()
        XCTAssertTrue(manager.sideEffectLifetimes.isEmpty)

        let firstSideEffectExecutedExpectation = expectation(description: "FirstSideEffect")
        _ = manager.render { context -> TestViewModel in
            context.runSideEffect(key: "key-1") { _ in
                firstSideEffectExecutedExpectation.fulfill()
            }
            return context.render(
                workflow: TestWorkflow(),
                key: "",
                outputMap: { _ in AnyWorkflowAction.noAction }
            )
        }

        wait(for: [firstSideEffectExecutedExpectation], timeout: 1)
        XCTAssertEqual(manager.sideEffectLifetimes.count, 1)
        XCTAssertEqual(manager.sideEffectLifetimes.keys.first, "key-1")

        let secondSideEffectExecutedExpectation = expectation(description: "SecondSideEffect")
        _ = manager.render { context -> TestViewModel in
            context.runSideEffect(key: "key-2") { _ in
                secondSideEffectExecutedExpectation.fulfill()
            }
            return context.render(
                workflow: TestWorkflow(),
                key: "",
                outputMap: { _ in AnyWorkflowAction.noAction }
            )
        }

        wait(for: [secondSideEffectExecutedExpectation], timeout: 1)
        XCTAssertEqual(manager.sideEffectLifetimes.count, 1)
        XCTAssertEqual(manager.sideEffectLifetimes.keys.first, "key-2")
    }

    func test_eventPipes_notRetainedByExternalSinks() {
        weak var weakEventPipe: WorkflowNode<TestWorkflow>.SubtreeManager.EventPipe?
        var externalSink: Sink<TestWorkflow.Event>?
        autoreleasepool {
            let manager = WorkflowNode<TestWorkflow>.SubtreeManager()

            manager.render({ context in
                externalSink = context.makeSink(of: TestWorkflow.Event.self)
            }, workflow: TestWorkflow())

            weakEventPipe = manager.eventPipes.last

            XCTAssertEqual(manager.eventPipes.count, 1)
            XCTAssertNotNil(weakEventPipe)
        }

        XCTAssertNotNil(externalSink)
        XCTAssertNil(weakEventPipe)
    }
}

private struct TestViewModel {
    var onTap: () -> Void
    var onToggle: () -> Void
}

private struct ParentWorkflow: Workflow {
    struct State {}
    typealias Event = TestWorkflow.Output
    typealias Output = Never

    func makeInitialState() -> State {
        return State()
    }

    func render(state: State, context: RenderContext<ParentWorkflow>) -> Never {
        fatalError()
    }
}

private struct TestWorkflow: Workflow {
    enum State {
        case foo
        case bar
    }

    enum Event: WorkflowAction {
        typealias WorkflowType = TestWorkflow

        case changeState
        case sendOutput

        func apply(toState state: inout TestWorkflow.State) -> TestWorkflow.Output? {
            switch self {
            case .changeState:
                switch state {
                case .foo: state = .bar
                case .bar: state = .foo
                }
                return nil
            case .sendOutput:
                return .helloWorld
            }
        }
    }

    enum Output {
        case helloWorld
    }

    func makeInitialState() -> State {
        return .foo
    }

    func render(state: State, context: RenderContext<TestWorkflow>) -> TestViewModel {
        let sink = context.makeSink(of: Event.self)

        return TestViewModel(
            onTap: { sink.send(.sendOutput) },
            onToggle: { sink.send(.changeState) }
        )
    }
}

// MARK: Testing conveniences

private extension WorkflowSession {
    static func testing() -> WorkflowSession {
        struct SessionTestWorkflow: Workflow {
            typealias State = Void
            typealias Rendering = Void

            func render(state: Void, context: RenderContext<SessionTestWorkflow>) {
                XCTFail("SessionTestWorkflow should never be rendered")
            }
        }

        return WorkflowSession(
            workflow: SessionTestWorkflow(),
            renderKey: "testing",
            parent: .none
        )
    }
}

private extension WorkflowNode.SubtreeManager {
    convenience init() {
        self.init(
            session: .testing(),
            observer: nil
        )
    }
}

private extension WorkflowNode.SubtreeManager where WorkflowType == ParentWorkflow {
    func render<Rendering>(
        _ actions: (RenderContext<WorkflowType>) -> Rendering
    ) -> Rendering {
        render(actions, workflow: ParentWorkflow())
    }
}

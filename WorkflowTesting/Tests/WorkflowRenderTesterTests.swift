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

import Workflow
import WorkflowTesting
import XCTest

final class WorkflowRenderTesterTests: XCTestCase {
    func test_render() {
        let renderTester = TestWorkflow(initialText: "initial").renderTester()
        var testedAssertion = false

        renderTester
            .render { screen in
                XCTAssertEqual("initial", screen.text)
                testedAssertion = true
            }
            .assert(
                state: TestWorkflow.State(
                    text: "initial",
                    substate: .idle
                )
            )

        XCTAssertTrue(testedAssertion)
    }

    func test_simple_render() {
        let renderTester = TestWorkflow(initialText: "initial").renderTester()

        renderTester
            .render { screen in
                XCTAssertEqual("initial", screen.text)
            }
            .assertNoAction()
    }

    func test_simple_render_throw() throws {
        let renderTester = TestWorkflow(initialText: "initial").renderTester()

        try renderTester
            .render { screen in
                let text = try XCTUnwrap(screen.text)
                XCTAssertEqual("initial", text)
            }
            .assertNoAction()
    }

    func test_action() {
        let renderTester = TestWorkflow(initialText: "initial").renderTester()

        renderTester
            .render { screen in
                XCTAssertEqual("initial", screen.text)
                screen.tapped()
            }
            .assert(
                state: TestWorkflow.State(
                    text: "initial",
                    substate: .waiting
                )
            )
    }

    func test_sideEffects() {
        let renderTester = SideEffectWorkflow().renderTester()

        renderTester
            .expectSideEffect(
                key: TestSideEffectKey(),
                producingAction: SideEffectWorkflow.Action.testAction
            )
            .render { _ in }
            .assert(state: .success)
    }

    func test_output() {
        OutputWorkflow()
            .renderTester()
            .render { rendering in
                rendering.tapped()
            }
            .assert(output: .success)
    }

    func test_ignoredOutput() {
        OutputIgnoringWorkflow(text: "hello")
            .renderTester()
            .expectWorkflowIgnoringOutput(
                type: ChildWorkflow.self,
                producingRendering: "olleh"
            )
            .render { rendering in
                XCTAssertEqual("olleh", rendering)
            }
            .assertNoOutput()
    }

    func test_ignoredOutput_opaqueChild() {
        OpaqueChildOutputIgnoringWorkflow(
            childProvider: {
                OutputWorkflow()
                    .mapRendering { _ in "screen" }
                    .asAnyWorkflow()
            }
        )
        .renderTester()
        .expectWorkflowIgnoringOutput(
            type: AnyWorkflow<String, OutputWorkflow.Output>.self,
            producingRendering: "test"
        )
        .render { rendering in
            XCTAssertEqual(rendering, "test")
        }
    }

    func test_opaqueChild() {
        OpaqueChildWorkflow(
            childProvider: {
                MockChildWorkflow().asAnyWorkflow()
            }
        )
        .renderTester()
        .expectWorkflow(
            type: MockChildWorkflow.self,
            producingRendering: "test"
        )
        .render { rendering in
            XCTAssertEqual(rendering, "test")
        }
    }

    func test_childWorkflow() {
        ParentWorkflow(initialText: "hello")
            .renderTester()
            .expectWorkflow(
                type: ChildWorkflow.self,
                producingRendering: "olleh"
            )
            .render { rendering in
                XCTAssertEqual("olleh", rendering)
            }
            .assertNoAction()
    }

    func test_childWorkflowAction() {
        ParentWorkflow(initialText: "hello")
            .renderTester()
            .expectWorkflow(
                type: ChildWorkflow.self,
                producingRendering: "olleh",
                producingOutput: ChildWorkflow.Output.success
            )
            .render { rendering in
                XCTAssertEqual("olleh", rendering)
            }.assert(action: ParentWorkflow.Action.childSuccess)
    }

    func test_childWorkflowOutput() {
        // Test that a child emitting an output is handled as an action by the parent
        ParentWorkflow(initialText: "hello")
            .renderTester()
            .expectWorkflow(
                type: ChildWorkflow.self,
                producingRendering: "olleh",
                producingOutput: .failure
            )
            .render { rendering in
                XCTAssertEqual("olleh", rendering)
            }
            .assertNoOutput()
            .verifyState { state in
                XCTAssertEqual("Failed", state.text)
            }
            .assertStateModifications { state in
                state.text = "Failed"
            }
    }
}

private struct TestWorkflow: Workflow {
    /// Input
    var initialText: String

    /// Output
    enum Output: Equatable {
        case first
    }

    struct State: Equatable {
        var text: String
        var substate: Substate
        enum Substate: Equatable {
            case idle
            case waiting
        }
    }

    func makeInitialState() -> State {
        State(text: initialText, substate: .idle)
    }

    func render(state: State, context: RenderContext<TestWorkflow>) -> TestScreen {
        let sink = context.makeSink(of: Action.self)

        switch state.substate {
        case .idle:
            break
        case .waiting:
            break
        }

        return TestScreen(
            text: state.text,
            tapped: {
                sink.send(.tapped)
            }
        )
    }
}

extension TestWorkflow {
    enum Action: WorkflowAction, Equatable {
        typealias WorkflowType = TestWorkflow

        case tapped
        case asyncSuccess

        func apply(toState state: inout TestWorkflow.State, context: ApplyContext<WorkflowType>) -> TestWorkflow.Output? {
            switch self {
            case .tapped:
                state.substate = .waiting

            case .asyncSuccess:
                state.substate = .idle
            }
            return nil
        }
    }
}

private struct OutputWorkflow: Workflow {
    enum Output {
        case success
        case failure
    }

    struct State {}

    func makeInitialState() -> OutputWorkflow.State {
        State()
    }

    enum Action: WorkflowAction {
        typealias WorkflowType = OutputWorkflow

        case emit

        func apply(toState state: inout OutputWorkflow.State, context: ApplyContext<WorkflowType>) -> OutputWorkflow.Output? {
            switch self {
            case .emit:
                .success
            }
        }
    }

    typealias Rendering = TestScreen

    func render(state: State, context: RenderContext<OutputWorkflow>) -> TestScreen {
        let sink = context.makeSink(of: Action.self)

        return TestScreen(text: "value", tapped: {
            sink.send(.emit)
        })
    }
}

private struct OutputIgnoringWorkflow: Workflow {
    typealias State = Void
    typealias Rendering = ChildWorkflow.Rendering

    var text: String

    func render(state: Void, context: RenderContext<OutputIgnoringWorkflow>) -> Rendering {
        ChildWorkflow(text: text).ignoringOutput().rendered(in: context)
    }
}

private struct MockChildWorkflow: Workflow {
    typealias State = Void
    typealias Rendering = String

    func render(state: Void, context: RenderContext<MockChildWorkflow>) -> String {
        XCTFail("should never be rendered")
        return ""
    }
}

private struct OpaqueChildWorkflow: Workflow {
    typealias State = Void
    typealias Rendering = String

    var childProvider: () -> AnyWorkflow<String, Never>

    func render(state: Void, context: RenderContext<Self>) -> Rendering {
        childProvider()
            .rendered(in: context)
    }
}

private struct OpaqueChildOutputIgnoringWorkflow: Workflow {
    typealias State = Void
    typealias Rendering = String

    var childProvider: () -> AnyWorkflow<String, OutputWorkflow.Output>

    func render(state: Void, context: RenderContext<Self>) -> Rendering {
        childProvider()
            .ignoringOutput()
            .rendered(in: context)
    }
}

private struct TestSideEffectKey: Hashable {
    let key: String = "Test Side Effect"
}

private struct SideEffectWorkflow: Workflow {
    enum State: Equatable {
        case idle
        case success
    }

    var prop = "hi"

    enum Action: WorkflowAction {
        case testAction

        typealias WorkflowType = SideEffectWorkflow

        func apply(
            toState state: inout SideEffectWorkflow.State,
            context: ApplyContext<WorkflowType>
        ) -> SideEffectWorkflow.Output? {
            switch self {
            case .testAction:
                state = .success
            }
            return nil
        }
    }

    typealias Rendering = TestScreen

    func render(state: State, context: RenderContext<SideEffectWorkflow>) -> TestScreen {
        context.runSideEffect(key: TestSideEffectKey()) { _ in }

        return TestScreen(text: "value", tapped: {})
    }

    func makeInitialState() -> State {
        .idle
    }
}

private struct TestScreen {
    var text: String?
    var tapped: () -> Void
}

private struct ParentWorkflow: Workflow {
    typealias Output = Never

    var initialText: String

    struct State: Equatable {
        var text: String
    }

    func makeInitialState() -> ParentWorkflow.State {
        State(text: initialText)
    }

    enum Action: WorkflowAction {
        typealias WorkflowType = ParentWorkflow

        case childSuccess
        case childFailure

        func apply(
            toState state: inout ParentWorkflow.State,
            context: ApplyContext<WorkflowType>
        ) -> Never? {
            switch self {
            case .childSuccess:
                state.text = String(state.text.reversed())

            case .childFailure:
                state.text = "Failed"
            }

            return nil
        }
    }

    func render(state: ParentWorkflow.State, context: RenderContext<ParentWorkflow>) -> String {
        ChildWorkflow(text: state.text)
            .mapOutput { output -> Action in
                switch output {
                case .success:
                    return .childSuccess
                case .failure:
                    return .childFailure
                }
            }
            .rendered(in: context)
    }
}

private struct ChildWorkflow: Workflow {
    enum Output: Equatable {
        case success
        case failure
    }

    var text: String

    struct State {}

    func makeInitialState() -> ChildWorkflow.State {
        State()
    }

    func render(state: ChildWorkflow.State, context: RenderContext<ChildWorkflow>) -> String {
        String(text.reversed())
    }
}

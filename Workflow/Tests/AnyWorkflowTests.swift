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

public class AnyWorkflowTests: XCTestCase {
    func testRendersWrappedWorkflow() {
        let workflow = AnyWorkflow(SimpleWorkflow(string: "asdf"))
        let node = WorkflowNode(workflow: PassthroughWorkflow(child: workflow))

        XCTAssertEqual(node.render(), "fdsa")
    }

    func testMapRendering() {
        let workflow = SimpleWorkflow(string: "asdf")
            .mapRendering { string -> String in
                string + "dsa"
            }
        let node = WorkflowNode(workflow: PassthroughWorkflow(child: workflow))

        XCTAssertEqual(node.render(), "fdsadsa")
    }

    func testOnOutput() {
        let host = WorkflowHost(workflow: OnOutputWorkflow())

        let renderingExpectation = expectation(description: "Waiting for rendering")
        host.rendering.producer.startWithValues { rendering in
            if rendering {
                renderingExpectation.fulfill()
            }
        }

        let outputExpectation = expectation(description: "Waiting for output")
        host.output.observeValues { output in
            if output {
                outputExpectation.fulfill()
            }
        }
        wait(for: [renderingExpectation, outputExpectation], timeout: 1)
    }

    func testOnlyWrapsOnce() {
        // direct initializer
        do {
            let base = OnOutputWorkflow()
            let wrappedOnce = AnyWorkflow(base)
            let wrappedTwice = AnyWorkflow(wrappedOnce)

            XCTAssertNotNil(wrappedOnce.base as? OnOutputWorkflow)
            XCTAssertNotNil(wrappedTwice.base as? OnOutputWorkflow)
        }

        // method chaining
        do {
            let base = OnOutputWorkflow()
            let wrappedOnce = base.asAnyWorkflow()
            let wrappedTwice = base.asAnyWorkflow().asAnyWorkflow()

            XCTAssertNotNil(wrappedOnce.base as? OnOutputWorkflow)
            XCTAssertNotNil(wrappedTwice.base as? OnOutputWorkflow)
        }
    }

    func testBaseValue() {
        let erased = OnOutputWorkflow().asAnyWorkflow()

        XCTAssertNotNil(erased.base as? OnOutputWorkflow)
    }
}

/// Has no state or output, simply renders a reversed string
private struct PassthroughWorkflow<Rendering>: Workflow {
    var child: AnyWorkflow<Rendering, Never>
}

extension PassthroughWorkflow {
    struct State {}

    func makeInitialState() -> State {
        State()
    }

    func render(state: State, context: RenderContext<PassthroughWorkflow<Rendering>>) -> Rendering {
        child.rendered(in: context)
    }
}

/// Has no state or output, simply renders a reversed string
private struct SimpleWorkflow: Workflow {
    var string: String
}

extension SimpleWorkflow {
    struct State {}

    func makeInitialState() -> State {
        State()
    }

    func render(state: State, context: RenderContext<SimpleWorkflow>) -> String {
        String(string.reversed())
    }
}

private struct OnOutputWorkflow: Workflow {
    typealias State = Bool
    typealias Rendering = Bool
    typealias Output = Bool

    func makeInitialState() -> Bool {
        false
    }

    func render(state: State, context: RenderContext<OnOutputWorkflow>) -> Bool {
        OnOutputChildWorkflow()
            .onOutput { state, output in
                state = output
                return output
            }
            .running(in: context)
        return state
    }
}

private struct OnOutputChildWorkflow: Workflow {
    typealias State = Void
    typealias Output = Bool
    typealias Rendering = Void

    func render(state: Void, context: RenderContext<OnOutputChildWorkflow>) {
        let sink = context.makeOutputSink()
        DispatchQueue.main.async {
            sink.send(true)
        }
    }
}

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

import Foundation

/// `RenderLatestOutputWorkflow` accepts a `Workflow` with `Void` Rendering
/// and projects the latest `Output` from the `Workflow` as a `Rendering` of the `Workflow`.
///
/// This can be used to consume the `Output` of a `Workflow` without having to update `State` with the value.
///
/// ex:
/// ```
/// let data = DataFetchWorker()
///     .renderLatestOutput(initialValue: .loading)
///     .rendered(in: context)
/// ```
///
public struct RenderLatestOutputWorkflow<Output>: Workflow {
    public typealias State = Output
    public typealias Rendering = Output
    public typealias Output = Never

    private let initialValue: Output
    private let childWorkflow: AnyWorkflow<Void, Output>

    /// Initialize `RenderLatestOutputWorkflow`
    /// - Parameters:
    ///   - workflow: Type conforming to `AnyWorkflowConvertible`, with `Void` Rendering.
    ///   - initialValue: Value to start with. This will be rendered until an `Output` is emitted.
    init<WorkflowType: AnyWorkflowConvertible>(workflow: WorkflowType, initialValue: Output) where WorkflowType.Rendering == Void, WorkflowType.Output == Output {
        self.childWorkflow = workflow.asAnyWorkflow()
        self.initialValue = initialValue
    }

    public func makeInitialState() -> State {
        initialValue
    }

    public func render(state: State, context: RenderContext<Self>) -> Rendering {
        childWorkflow
            .onOutput { state, output in
                state = output
                return nil
            }.rendered(in: context)
        return state
    }
}

public extension AnyWorkflowConvertible where Rendering == Void {
    /// Convenience to initialize `RenderLatestOutputWorkflow`
    /// - Parameter startingWith: Value to start with. This will be rendered until an `Output` is emitted.
    /// - Returns: `RenderLatestOutputWorkflow`
    ///
    /// Note: To test using `RenderTester`, you can use the `expectLatestOutputRenderingWorkflow` API.
    func renderLatestOutput(startingWith: Output) -> RenderLatestOutputWorkflow<Output> {
        RenderLatestOutputWorkflow(workflow: self, initialValue: startingWith)
    }
}

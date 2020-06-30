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
import Workflow

extension RenderContext {
    @available(*, deprecated, message: "Use `Worker().running(in:, outputMap:)` instead.")
    public func awaitResult<W, Action>(for worker: W, outputMap: @escaping (W.Output) -> Action) where W: Worker, Action: WorkflowAction, WorkflowType == Action.WorkflowType, W.Rendering == Void {
        worker
            .mapOutput { outputMap($0) }
            .running(in: self)
    }

    @available(*, deprecated, message: "Use `Worker().running(in:)` instead.")
    public func awaitResult<W>(for worker: W) where W: Worker, W.Output: WorkflowAction, WorkflowType == W.Output.WorkflowType, W.Rendering == Void {
        awaitResult(for: worker, outputMap: { $0 })
    }

    @available(*, deprecated, message: "Use `Worker().running(in:)` instead.")
    public func awaitResult<W>(for worker: W, onOutput: @escaping (W.Output, inout WorkflowType.State) -> WorkflowType.Output?) where W: Worker, W.Rendering == Void {
        awaitResult(for: worker) { output in
            AnyWorkflowAction<WorkflowType> { state in
                onOutput(output, &state)
            }
        }
    }
}

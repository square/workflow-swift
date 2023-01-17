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

extension AnyWorkflow where Output == Never {
    /// Creates an AnyWorkflow that does nothing but echo the given `rendering`.
    ///
    /// - Note: To use with `RenderTester`, use `expectRenderingWorkflow`
    public init(rendering: Rendering) {
        self = RenderingWorkflow(rendering: rendering).asAnyWorkflow()
    }
}

struct RenderingWorkflow<Rendering>: Workflow {
    var rendering: Rendering
    typealias Output = Never
    typealias State = Void

    func render(state: State, context: RenderContext<Self>) -> Rendering {
        return rendering
    }
}

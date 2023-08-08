/*
 * Copyright 2023 Square Inc.
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
import SwiftUI
import Workflow

struct WorkflowView2<WorkflowType: Workflow, Content: View>: View {
    let workflow: WorkflowType
    let content: (WorkflowType.Rendering) -> Content

    @StateObject private var host: ObservableWorkflowHost<WorkflowType>

    init(
        workflow: WorkflowType,
        content: @escaping (WorkflowType.Rendering) -> Content
    ) {
        self.workflow = workflow
        self.content = content

        // Don't move `ObservableWorkflowHost` initialization outside the `wrappedValue` parameter
        // autoclosure, or the host will be reinitialized on every `WorkflowView.init`.
        _host = StateObject(wrappedValue: ObservableWorkflowHost(workflow: workflow))

        // TODO: Avoid this `update` when host was just initialized with same value
        host.update(workflow: workflow)
    }

    var body: some View {
        content(host.rendering)
    }
}

final class ObservableWorkflowHost<WorkflowType: Workflow>: ObservableObject {
    @Published private(set) var rendering: WorkflowType.Rendering
    private let host: WorkflowHost<WorkflowType>
    private let (lifetime, token) = Lifetime.make()

    init(workflow: WorkflowType) {
        self.host = WorkflowHost(
            workflow: workflow,
            observers: [],
            debugger: nil
        )
        self.rendering = host.rendering.value

        host.rendering
            .signal
            .take(during: lifetime)
            .observeValues { [weak self] in self?.rendering = $0 }
    }

    func send<Action: WorkflowAction>(_ action: Action) where Action.WorkflowType == WorkflowType {
        fatalError("not implemented")
    }

    func update(workflow: WorkflowType) {
        host.update(workflow: workflow)
    }
}

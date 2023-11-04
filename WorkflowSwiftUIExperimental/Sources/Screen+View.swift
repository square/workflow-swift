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

#if canImport(UIKit)

import SwiftUI
import Workflow
import WorkflowUI

public extension Screen where Self: View {
    func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
        return ViewControllerDescription(
            type: UIHostingController<RootView<Self>>.self,
            environment: environment,
            build: {
                UIHostingController(
                    rootView: RootView(
                        model: RootViewModel(
                            content: self,
                            environment: environment
                        )
                    )
                )
            },
            update: { hostingController in
                let object = hostingController.rootView.model
                object.content = self
                object.environment = environment
            }
        )
    }
}

private final class RootViewModel<Content: View>: ObservableObject {
    @Published var content: Content
    @Published var environment: ViewEnvironment

    init(content: Content, environment: ViewEnvironment) {
        self.content = content
        self.environment = environment
    }
}

private struct RootView<Content: View>: View {
    @ObservedObject var model: RootViewModel<Content>

    var body: some View {
        model.content
            .environment(\.viewEnvironment, model.environment)
    }
}

#endif

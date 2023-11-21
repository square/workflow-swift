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

import MarketUI
import MarketWorkflowUI
import ViewEnvironment
import Workflow
import WorkflowSwiftUIExperimental
import WorkflowUI

struct MainViewModel {
    @WorkflowBinding var title: String

    @WorkflowBinding var allCapsToggleIsOn: Bool
    let allCapsToggleIsEnabled: Bool

    let didTapPushScreen: () -> Void
    let didTapPresentScreen: () -> Void

    let didTapClose: (() -> Void)?
}

extension MainViewModel: SwiftUIScreen {
    func makeView() -> some View {
        MainView(model: self)
    }
}

struct MainView: View {
    let model: MainViewModel

    @Environment(\.viewEnvironment.marketStylesheet) private var styles: MarketStylesheet
    @Environment(\.viewEnvironment.marketContext) private var context: MarketContext

    @State var title: String = "Test"

    @State var uuid = UUID()

    var body: some View {
        ScrollView { VStack {
            Text("Title")
                .font(Font(styles.headers.inlineSection20.heading.text.font))

            TitleView(title: model.$title)

            Spacer(minLength: styles.spacings.spacing50)

            Text("Navigation")
                .font(Font(styles.headers.inlineSection20.heading.text.font))

            Button(
                "Push Screen",
                action: model.didTapPushScreen
            )

            Button(
                "Present Screen",
                action: model.didTapPresentScreen
            )

            // future notes:
            // we are seeing an invalidation on TitleView when clicking this button. Presumbly SwiftUI thinks the binding is changing. We are debugging to figure out how to make SwiftUI see the bindings as the same across updates. Reusing the Binding inside WorkflowBinding removes the invalidation of "@self" in TitleView but still shows _title.
            // Ideas:
            // - get the binding reuse to actually work
            // - Remove contents of get/set and replace with dummy closures to see if it's the closures.
            //

            Button("Invalidate: \(uuid)") {
                uuid = UUID()
            }

        } }
    }
}

extension MainViewModel: MarketBackStackContentScreen {
    func backStackItem(in environment: ViewEnvironment) -> MarketUI.MarketNavigationItem {
        MarketNavigationItem(
            title: .text(.init(regular: title)),
            backButton: didTapClose.map { .close(onTap: $0) } ?? .automatic()
        )
    }

    var backStackIdentifier: AnyHashable? { nil }
}

#if DEBUG

import SwiftUI

struct MainScreen_Preview: PreviewProvider {
    @State static var title = "New item"
    @State static var allCapsToggleIsOn = false

    static var previews: some View {
        MainViewModel(
            title: WorkflowBinding($title),
            allCapsToggleIsOn: WorkflowBinding($allCapsToggleIsOn),
            allCapsToggleIsEnabled: true,
            didTapPushScreen: {},
            didTapPresentScreen: {},
            didTapClose: {}
        )
        .asMarketBackStack()
        .marketPreview()
    }
}

#endif

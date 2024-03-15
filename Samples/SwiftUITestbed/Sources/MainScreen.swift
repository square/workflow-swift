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
import Perception // for WithPerceptionTracking
import ViewEnvironment
import WorkflowSwiftUIExperimental
import WorkflowUI

struct MainScreen: SwiftUIScreen {
    typealias Model = StoreModel<MainWorkflow.State, MainWorkflow.Action>
    var model: Model

    public static func makeView(store: Store<Model>) -> some View {
        MainView(store: store)
    }
}

private struct MainView: View {
    typealias Model = StoreModel<MainWorkflow.State, MainWorkflow.Action>
    @Perception.Bindable var store: Store<Model>

    @Environment(\.viewEnvironment.marketStylesheet) private var styles: MarketStylesheet
    @Environment(\.viewEnvironment.marketContext) private var context: MarketContext

    enum Field: Hashable {
        case title
    }

    @FocusState var focusedField: Field?

    var body: some View {
        WithPerceptionTracking { ScrollView { VStack {
            let _ = Self._printChanges()

            // TODO:
            // - suppress double render from textfield binding?

            Text("Title")
                .font(Font(styles.headers.inlineSection20.heading.text.font))

            TextField(
                "Text",
                text: $store.title
                // alternatively:
                // text: store.binding(for: \.title, action: \.titleChanged)
            )
            .focused($focusedField, equals: .title)
            .onAppear { focusedField = .title }

            Text("What you typed: \(store.title)")

            ToggleRow(
                style: context.stylesheets.testbed.toggleRow,
                label: "All Caps",
                isEnabled: store.allCapsToggleIsEnabled,
                isOn: $store.isAllCaps
            )

            Button("Append *", action: store.action(.appendStar))

            Spacer(minLength: styles.spacings.spacing50)

            Text("Navigation")
                .font(Font(styles.headers.inlineSection20.heading.text.font))

            Button(
                "Push Screen",
                action: store.action(.pushScreen)
            )

            Button(
                "Present Screen",
                action: store.action(.presentScreen)
            )

            Button(
                "Resign Focus",
                action: { focusedField = nil }
            )

        } } }
    }
}

extension MainScreen: MarketBackStackContentScreen {
    func backStackItem(in environment: ViewEnvironment) -> MarketUI.MarketNavigationItem {
        MarketNavigationItem(
            title: .text(.init(regular: model.title)),
            backButton: .close(onTap: { fatalError("TODO") }) // didTapClose.map { .close(onTap: $0) } ?? .automatic()
        )
    }

    var backStackIdentifier: AnyHashable? { nil }
}

#if DEBUG

import SwiftUI

struct MainScreen_Preview: PreviewProvider {
    static var previews: some View {
        MainWorkflow(
            didClose: nil
        )
        .mapRendering { MainScreen(model: $0).asMarketBackStack() }
        .marketPreview { output in

        }
    }
}

#endif

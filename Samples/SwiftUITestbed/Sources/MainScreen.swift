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

// Compiler requires explicit conformance to `Screen`, or else: "Conditional
// conformance of type 'ViewModel<State, Action>' to protocol 'SwiftUIScreen'
// does not imply conformance to inherited protocol 'Screen'"
extension MainWorkflow.Rendering: SwiftUIScreen, Screen {
    static func makeView(store: Store<State>, sendAction: @escaping (Action) -> Void) -> some View {
        MainScreenView(model: store)
    }
}

private struct MainScreenView: View {
    @BindableStore var model: Store<MainWorkflow.State>

    @Environment(\.viewEnvironment.marketStylesheet) private var styles: MarketStylesheet
    @Environment(\.viewEnvironment.marketContext) private var context: MarketContext

    enum Field: Hashable {
        case title
    }

    @FocusState var focusedField: Field?

    var body: some View {
        WithPerceptionTracking { ScrollView { VStack {
            Text("Title")
                .font(Font(styles.headers.inlineSection20.heading.text.font))

            TextField(
                "Text",
                text: $model.title
            )
            .focused($focusedField, equals: .title)
            .onAppear { focusedField = .title }

            ToggleRow(
                style: context.stylesheets.testbed.toggleRow,
                label: "All Caps",
                isEnabled: model.allCapsToggleIsEnabled,
                isOn: $model.allCapsToggleIsOn
            )

            Spacer(minLength: styles.spacings.spacing50)

            Text("Navigation")
                .font(Font(styles.headers.inlineSection20.heading.text.font))

            Button(
                "Push Screen",
                action: { fatalError("TODO") }
            )

            Button(
                "Present Screen",
                action: { fatalError("TODO") }
            )

            Button(
                "Resign Focus",
                action: { focusedField = nil }
            )

        } } }
    }
}

extension MainWorkflow.Rendering: MarketBackStackContentScreen {
    func backStackItem(in environment: ViewEnvironment) -> MarketUI.MarketNavigationItem {
        MarketNavigationItem(
            title: .text(.init(regular: state.title)),
            backButton: .close(onTap: { fatalError("TODO") }) // didTapClose.map { .close(onTap: $0) } ?? .automatic()
        )
    }

    var backStackIdentifier: AnyHashable? { nil }
}

#if DEBUG

import SwiftUI

struct MainScreen_Preview: PreviewProvider {
    static var previews: some View {
        MainWorkflow.Rendering(
            state: .init(title: "Test"),
            sendAction: { _ in }
        )
        .asMarketBackStack()
        .marketPreview()
    }
}

#endif

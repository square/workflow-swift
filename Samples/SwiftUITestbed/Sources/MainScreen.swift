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
import WorkflowSwiftUIExperimental

struct MainScreen: SwiftUIScreen {
    let title: String
    let didChangeTitle: (String) -> Void

    let allCapsToggleIsOn: Bool
    let allCapsToggleIsEnabled: Bool
    let didChangeAllCapsToggle: (Bool) -> Void

    let didTapPushScreen: () -> Void
    let didTapPresentScreen: () -> Void

    let didTapClose: (() -> Void)?

    static func makeView(model: ObservableValue<MainScreen>) -> some View {
        MainScreenView(model: model)
    }
}

private struct MainScreenView: View {
    @ObservedObject var model: AnyStore<MainScreen>

    @Environment(\.viewEnvironment.marketStylesheet) private var styles: MarketStylesheet
    @Environment(\.viewEnvironment.marketContext) private var context: MarketContext

    enum Field: Hashable {
        case title
    }

    @FocusState var focusedField: Field?

    var body: some View {
        ScrollView { VStack {
            Text("Title")
                .font(Font(styles.headers.inlineSection20.heading.text.font))

            TextField(
                "Text",
                text: model.binding(
                    get: \.title,
                    set: \.didChangeTitle
                )
            )
            .focused($focusedField, equals: .title)
            .onAppear { focusedField = .title }

            ToggleRow(
                style: context.stylesheets.testbed.toggleRow,
                label: "All Caps",
                isEnabled: model.allCapsToggleIsEnabled,
                isOn: model.allCapsToggleIsOn,
                onChange: model.didChangeAllCapsToggle
            )

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

            Button(
                "Resign Focus",
                action: { focusedField = nil }
            )

        } }
    }
}

extension MainScreen: MarketBackStackContentScreen {
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
    static var previews: some View {
        MainScreen(
            title: "New item",
            didChangeTitle: { _ in },
            allCapsToggleIsOn: true,
            allCapsToggleIsEnabled: true,
            didChangeAllCapsToggle: { _ in },
            didTapPushScreen: {},
            didTapPresentScreen: {},
            didTapClose: {}
        )
        .asMarketBackStack()
        .marketPreview()
    }
}

#endif

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

import BlueprintUI
import MarketUI
import MarketWorkflowUI
import SwiftUI
import ViewEnvironment

struct MainScreen: MarketScreen {
    enum Field: Hashable {
        case title
    }

    @BlueprintUI.FocusState var focusedField: Field?

    let title: String
    let didChangeTitle: (String) -> Void

    let allCapsToggleIsOn: Bool
    let allCapsToggleIsEnabled: Bool
    let didChangeAllCapsToggle: (Bool) -> Void

    let didTapPushScreen: () -> Void
    let didTapPresentScreen: () -> Void

    let didTapClose: (() -> Void)?

    func element(
        in context: MarketWorkflowUI.MarketScreenContext,
        with styles: MarketTheming.MarketStylesheet
    ) -> BlueprintUI.Element {
        Column(
            alignment: .fill,
            underflow: .justifyToStart,
            minimumSpacing: styles.spacings.spacing200
        ) {
            MarketInlineSectionHeader(
                style: styles.headers.inlineSection20,
                title: "Title"
            )

            MarketTextField(
                style: styles.fields.textField,
                label: "Text",
                text: title,
                onChange: didChangeTitle,
                onReturn: { _ in focusedField = nil }
            )
            .focused(when: $focusedField, equals: .title)
            .onAppear { focusedField = .title }

            ToggleRow(
                style: context.stylesheets.testbed.toggleRow,
                label: "All Caps",
                isEnabled: allCapsToggleIsEnabled,
                isOn: allCapsToggleIsOn,
                onChange: didChangeAllCapsToggle
            )

            Spacer(styles.spacings.spacing50)

            MarketInlineSectionHeader(
                style: styles.headers.inlineSection20,
                title: "Navigation"
            )

            MarketButton(
                style: styles.button(rank: .secondary),
                text: "Push Screen",
                onTap: didTapPushScreen
            )

            MarketButton(
                style: styles.button(rank: .secondary),
                text: "Present Screen",
                onTap: didTapPresentScreen
            )

            MarketButton(
                style: styles.button(rank: .secondary),
                text: "Resign Focus",
                onTap: { focusedField = nil }
            )
        }
        .marketScreenContent()
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

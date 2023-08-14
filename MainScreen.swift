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
import ViewEnvironment

struct MainScreen: MarketScreen {
    let title: String
    let didChangeTitle: (String) -> Void
    let didTapPushScreen: () -> Void
    let didTapPresentScreen: () -> Void
    let didTapClose: (() -> Void)?

    func element(
        in context: MarketWorkflowUI.MarketScreenContext,
        with styles: MarketTheming.MarketStylesheet
    ) -> BlueprintUI.Element {
        MarketScreenContent {
            Column(
                underflow: .justifyToStart,
                minimumSpacing: styles.spacings.spacing200
            ) {
                MarketTextField(
                    style: styles.fields.textField,
                    label: "Title",
                    text: title,
                    onChange: didChangeTitle
                )

                MarketButton(
                    style: styles.button(rank: .primary),
                    text: "Push Screen",
                    onTap: didTapPushScreen
                )

                MarketButton(
                    style: styles.button(rank: .primary),
                    text: "Present Screen",
                    onTap: didTapPresentScreen
                )
            }
        }
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

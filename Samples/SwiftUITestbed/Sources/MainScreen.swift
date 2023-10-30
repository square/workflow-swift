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

struct MainScreen: MarketScreen, Equatable {
    enum Field: Hashable {
        case title
    }

    @FocusState var focusedField: Field?

    let title: String
    let canClose: Bool
    let allCapsToggleIsOn: Bool
    let allCapsToggleIsEnabled: Bool

    let sink: StableSink<Action>

    func element(
        in context: MarketWorkflowUI.MarketScreenContext,
        with styles: MarketTheming.MarketStylesheet
    ) -> BlueprintUI.Element {
        MarketScreenContent {
            Column(
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
                    onChange: { sink.send(.changeTitle($0)) },
                    onReturn: { _ in focusedField = nil }
                )
                .focused(when: $focusedField, equals: .title)
                .onAppear { focusedField = .title }

                Row(
                    alignment: .center,
                    minimumSpacing: styles.spacings.spacing200
                ) {
                    MarketLabel(
                        textStyle: styles.typography.semibold20,
                        color: styles.colors.text10,
                        text: "All Caps"
                    )

                    MarketToggle(
                        style: styles.toggle.normal,
                        isOn: allCapsToggleIsOn,
                        isEnabled: allCapsToggleIsEnabled,
                        accessibilityLabel: "is all caps",
                        onChange: { sink.send(.changeAllCaps($0)) }
                    )
                }

                Spacer(styles.spacings.spacing50)

                MarketInlineSectionHeader(
                    style: styles.headers.inlineSection20,
                    title: "Navigation"
                )

                MarketButton(
                    style: styles.button(rank: .secondary),
                    text: "Push Screen",
                    onTap: sink.closure(.pushScreen)
                )

                MarketButton(
                    style: styles.button(rank: .secondary),
                    text: "Present Screen",
                    onTap: sink.closure(.presentScreen)
                )
            }
        }
    }
}

extension MainScreen: MarketBackStackContentScreen {
    func backStackItem(in environment: ViewEnvironment) -> MarketUI.MarketNavigationItem {
        MarketNavigationItem(
            title: .text(.init(regular: title)),
            backButton: canClose ? .close(onTap: sink.closure(.close)) : .automatic()
        )
    }

    var backStackIdentifier: AnyHashable? { nil }
}

extension MainScreen {
    enum Action {
        case pushScreen
        case presentScreen
        case changeTitle(String)
        case changeAllCaps(Bool)
        case close
    }
}

// I guess this could be upstreamed to Blueprint
extension FocusState: Equatable where Value: Equatable {
    public static func == (lhs: FocusState<Value>, rhs: FocusState<Value>) -> Bool {
        lhs.wrappedValue == rhs.wrappedValue
    }
}

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

struct ToggleRow: ProxyElement {
    var style: Style

    var label: String

    var isEnabled: Bool

    var isOn: Bool

    var onChange: (Bool) -> Void

    var elementRepresentation: Element {
        Row(
            alignment: .center,
            minimumSpacing: style.spacing
        ) {
            MarketLabel(
                style: style.label,
                text: label
            )
            .blockAccessibility()

            MarketToggle(
                style: style.toggle,
                isOn: isOn,
                isEnabled: isEnabled,
                accessibilityLabel: label,
                onChange: onChange
            )
        }
    }
}

extension ToggleRow {
    struct Style: Equatable {
        var spacing: CGFloat
        var label: MarketLabelStyle
        var toggle: MarketToggleStyle
    }
}
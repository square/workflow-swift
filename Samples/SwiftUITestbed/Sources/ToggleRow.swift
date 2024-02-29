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
import SwiftUI

struct ToggleRow: View {
    var style: Style

    var label: String

    var isEnabled: Bool

    @Binding var isOn: Bool

    var body: some View {
        let _ = Self._printChanges()
        HStack(
            alignment: .center,
            spacing: style.spacing
        ) {
            Text(label)
                .font(Font(style.label.text.font))
                .accessibilityHidden(true)

            Toggle(
                isOn: $isOn,
                label: EmptyView.init
            )
            .accessibilityLabel(label)
            // Required before iOS 16 to animate value changes not caused by interaction with toggle
            .animation(.default, value: isOn)
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

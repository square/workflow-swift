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

import MarketTheming

struct TestbedStylesheet: Stylesheet {
    var toggleRow: ToggleRow.Style

    init(context: SlicingContext) {
        let styles = context.stylesheets.market

        self.toggleRow = .init(
            spacing: styles.spacings.spacing200,
            label: .init(
                text: styles.typography.semibold20,
                color: styles.colors.text10
            ),
            toggle: styles.toggle.normal
        )
    }
}

extension Stylesheets {
    var testbed: TestbedStylesheet { self[stylesheetType: TestbedStylesheet.self] }
}

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

import SwiftUI

struct WithModel<Model, Content: View>: View {
    @ObservedObject private var model: ObservableObjectValue<Model>
    private let content: (ObservableObjectValue<Model>) -> Content

    init(
        _ model: ObservableObjectValue<Model>,
        @ViewBuilder content: @escaping (ObservableObjectValue<Model>) -> Content
    ) {
        self.model = model
        self.content = content
    }

    var body: Content {
        content(model)
    }
}

/*
 * Copyright 2020 Square Inc.
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
import Workflow
import WorkflowSwiftUI

struct TodoEditScreen: SwiftUIScreen, Equatable {
    // The title of this todo item.
    @Writable var title: String
    // The contents, or "note" of the todo.
    @Writable var note: String

    static func makeView(model: ObservableValue<TodoEditScreen>) -> some View {
        VStack {
            TextField("Title", text: model.$title)
                .font(.title)

            TextEditor(text: model.$note)
        }.padding()
    }
}

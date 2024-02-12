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
import WorkflowSwiftUI

struct TodoEditScreen: ObservableSwiftUIScreen {
    // The title of this todo item.
    var title: String
    // The contents, or "note" of the todo.
    var note: String

    // Callback for when the title or note changes
    var onTitleChanged: (String) -> Void
    var onNoteChanged: (String) -> Void
    
    static func makeView(model: ObservableValue<TodoEditScreen>) -> some View {
        VStack {
            TextField("Title", text: model.binding(
                get: \.title,
                set: { screen in { screen.onTitleChanged($0) }}
            ))
            .font(.title)
            
            TextEditor(text: model.binding(
                get: \.note,
                set: { screen in { screen.onNoteChanged($0) }}
            ))
        }.padding()
    }
}

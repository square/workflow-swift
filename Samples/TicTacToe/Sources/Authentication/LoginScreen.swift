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

struct LoginScreen: SwiftUIScreen {
    var title: String
    var email: String
    var onEmailChanged: (String) -> Void
    var password: String
    var onPasswordChanged: (String) -> Void
    var onLoginTapped: () -> Void

    static func makeView(model: ObservableValue<LoginScreen>) -> some View {
        VStack(spacing: 16) {
            Text(model.title)

            TextField(
                "email@address.com",
                text: model.binding(
                    get: \.email,
                    set: \.onEmailChanged
                )
            )
            .autocapitalization(.none)
            .autocorrectionDisabled()
            .textContentType(.emailAddress)

            SecureField(
                "password",
                text: model.binding(
                    get: \.password,
                    set: \.onPasswordChanged
                ),
                onCommit: model.onLoginTapped
            )

            Button("Login", action: model.onLoginTapped)
        }
        .frame(maxWidth: 400)
    }
}

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

public extension Binding {
    /// Initializer for creating a binding to plain, value-typed property of the enclosing SwiftUI View. This initializer works around an
    /// [animation issue] with `Toggle` in iOS 15.
    ///
    /// Native views that take a `Binding`, such as `Toggle` and `TextView`, after calling the binding's `set`,  will
    /// immediately re-call the same binding's `get`. That call to `get` will not reflect the new value just passed to `set` if `get`
    /// captures a value-typed property like this:
    ///
    /// ```
    /// struct MyView: View {
    ///     let isOn: Bool
    ///     let setIsOn: (Bool) -> Void
    ///
    ///     var body: some View {
    ///         Toggle(
    ///             isOn: .init(
    ///                 get: { isOn },
    ///                 set: setIsOn
    ///             ),
    ///             label: EmptyView.init
    ///         )
    ///     }
    /// }
    /// ```
    /// In `Toggle` in particular, in iOS 15 and earlier, that stale value appears to be the cause of an [animation issue].
    ///
    /// This initializer works around that issue by caching any value passed to `set` and preferentially returning that cached
    /// value for any subsequent `get` call.
    ///
    /// [animation issue]: https://github.com/square/workflow-swift/pull/253#issuecomment-1787933874
    init(
        initialValue: Value,
        set: @escaping (Value) -> Void
    ) {
        var value = initialValue
        self.init(
            get: { value },
            set: { newValue in
                value = newValue
                set(newValue)
            }
        )
    }
}

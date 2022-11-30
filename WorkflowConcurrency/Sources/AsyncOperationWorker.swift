/*
 * Copyright 2022 Square Inc.
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

import Foundation
import Workflow

/// Convenience to execute an async function in a worker.
///
/// Example of using an async function.
/// ```
/// func render(state: State, context: RenderContext<Self>) -> MyScreen {
///     AsyncOperationWorker(myAsyncFunction)
///         .mapOutput { MyAction($0) }
///         .running(in: context, key: "UniqueKey")
///
///     return MyScreen()
/// }
/// ```
///
/// Example of using a closure.
/// ```
/// func render(state: State, context: RenderContext<Self>) -> MyScreen {
///     AsyncOperationWorker {
///         return await asyncFunctionCall()
///     }
///         .mapOutput { MyAction($0) }
///         .running(in: context, key: "UniqueKey")
///
///     return MyScreen()
/// }
/// ```

@available(iOS 13.0, macOS 10.15, *)
public struct AsyncOperationWorker<OutputType>: Worker {
    private let operation: () async -> OutputType

    public init(_ operation: @escaping () async -> OutputType) {
        self.operation = operation
    }

    public func run() async -> OutputType {
        return await operation()
    }

    public typealias Output = OutputType

    public func isEquivalent(to otherWorker: AsyncOperationWorker) -> Bool {
        return true
    }
}

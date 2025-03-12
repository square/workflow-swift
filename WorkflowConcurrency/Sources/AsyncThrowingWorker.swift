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

/// Convenience to execute a throwing async function in a worker.
///
/// Example of using a throwing async function.
/// ```
/// func render(state: State, context: RenderContext<Self>) -> MyScreen {
///     AsyncOperationWorker(myAsyncThrowsFunction)
///         .mapOutput { MyResultAction($0) }
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
///         try await asyncFunctionCall()
///     }
///         .mapOutput { MyResultAction($0) }
///         .running(in: context, key: "UniqueKey")
///
///     return MyScreen()
/// }
/// ```
public struct AsyncThrowingWorker<Success>: Worker {
    public typealias Output = Result<Success, Error>

    private let operation: () async throws -> Success

    public init(_ operation: @escaping () async throws -> Success) {
        self.operation = operation
    }

    public func run() async -> Result<Success, Error> {
        do {
            return .success(try await operation())
        } catch {
            return .failure(error)
        }
    }

    public func isEquivalent(to otherWorker: AsyncThrowingWorker<Success>) -> Bool {
        true
    }
}

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

extension RenderContext {
    /// Creates `StateMutationSink`.
    ///
    /// To create a sink:
    /// ```
    /// let stateMutationSink = context.makeStateMutationSink()
    /// ```
    ///
    /// To mutate `State` on an event:
    /// ```
    /// stateMutationSink.send(\State.value, value: 10)
    /// ```
    public func makeStateMutationSink() -> StateMutationSink<WorkflowType> {
        let sink = makeSink(of: AnyWorkflowAction<WorkflowType>.self)
        return StateMutationSink(sink)
    }
}

/// StateMutationSink provides a `Sink` that helps mutate `State` using it's `KeyPath`.
public struct StateMutationSink<WorkflowType: Workflow> {
    let sink: Sink<AnyWorkflowAction<WorkflowType>>

    /// Sends message to `StateMutationSink` to update `State`'s value using the provided closure.
    ///
    /// - Parameters:
    ///   - update: The `State`` mutation to perform.
    public func send(_ update: @escaping (inout WorkflowType.State) -> Void) {
        sink.send(
            AnyWorkflowAction<WorkflowType> { state in
                update(&state)
                return nil
            }
        )
    }

    /// Sends message to `StateMutationSink` to update `State`'s value at `KeyPath` with `Value`.
    ///
    /// - Parameters:
    ///   - keyPath: Key path of `State` whose value needs to be mutated.
    ///   - value: Value to update `State` with.
    public func send<Value>(_ keyPath: WritableKeyPath<WorkflowType.State, Value>, value: Value) {
        send { $0[keyPath: keyPath] = value }
    }

    init(_ sink: Sink<AnyWorkflowAction<WorkflowType>>) {
        self.sink = sink
    }
}

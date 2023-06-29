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

/// A sink intended specifically to fulfill the `actionSink` requirement of ``SwiftUIScreen``. In order that the
/// `SwiftUIScreen` can automatically be `Equatable`, this sink is `Equatable` and always compares equal.
///
/// *TODO:* Should this really _always_ compare equal? Can we pass in some identity when initializing? Maybe some identifier from
/// the `RenderContext`, or even just the source location where the sink was initialized?
public struct ScreenActionSink<Value>: Equatable {
    private let sink: Sink<Value>

    public init(_ sink: Sink<Value>) {
        self.sink = sink
    }

    public func send(_ value: Value) {
        sink.send(value)
    }

    public static func noop<T>() -> ScreenActionSink<T> {
        ScreenActionSink<T>(Sink { _ in })
    }

    // MARK: Equatable

    public static func == (lhs: ScreenActionSink<Value>, rhs: ScreenActionSink<Value>) -> Bool {
        true
    }
}

public extension RenderContext {
    var actionSink: ScreenActionSink {}
}

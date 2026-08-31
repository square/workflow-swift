/*
 * Copyright 2026 Square Inc.
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

/// Fans values out to any number of independent `AsyncStream` consumers.
///
/// Each call to `makeStream` returns an independent stream: every consumer
/// receives every value yielded after its stream was created (subject to the
/// requested buffering policy), optionally preceded by an initial value.
/// Streams finish when `finish()` is called or when the multicaster is
/// deallocated.
@MainActor
final class AsyncMulticaster<Element> {
    private var continuations: [UUID: AsyncStream<Element>.Continuation] = [:]
    private var isFinished = false

    nonisolated init() {}

    func finish() {
        isFinished = true
        let existing = continuations
        continuations.removeAll()
        for continuation in existing.values {
            continuation.finish()
        }
    }

    deinit {
        // Continuations are Sendable; finishing them from a nonisolated
        // deinit is safe. (Stored-property access is permitted in deinit.)
        for continuation in continuations.values {
            continuation.finish()
        }
    }
}

// Yielding values into the fan-out streams requires `Element` to be `Sendable`:
// consumers may iterate their streams from arbitrary isolation domains, and a
// single value is delivered to every consumer.
extension AsyncMulticaster where Element: Sendable {
    func makeStream(
        bufferingPolicy: AsyncStream<Element>.Continuation.BufferingPolicy,
        initial: Element? = nil
    ) -> AsyncStream<Element> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: Element.self,
            bufferingPolicy: bufferingPolicy
        )

        guard !isFinished else {
            continuation.finish()
            return stream
        }

        if let initial {
            continuation.yield(initial)
        }

        let id = UUID()
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.continuations[id] = nil
            }
        }

        return stream
    }

    func yield(_ element: Element) {
        for continuation in continuations.values {
            continuation.yield(element)
        }
    }
}

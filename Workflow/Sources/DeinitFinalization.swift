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

/// Runs main-actor finalization work from a (nonisolated) `deinit`, matching
/// the dispatch semantics of an `isolated deinit` (SE-0371) without using
/// one — the Swift 6.3.2 optimizer crashes when compiling isolated deinits
/// of generic classes in release builds.
///
/// If the last reference was released from a main-actor task context, the
/// finalization runs inline, so callers that drop a reference can observe
/// teardown side effects synchronously. Otherwise — a release from the bare
/// main thread mid-operation, or from another thread — the finalization is
/// enqueued onto the main actor so it can't interleave with whatever
/// main-actor operation released the last reference (e.g. an in-progress
/// render pass).
///
/// The inline path also gives enqueued finalizations single-job cascade
/// semantics: once an enqueued finalization runs (inside a main-actor task),
/// any deinits it triggers take the inline path, so an entire subtree tears
/// down within one main-actor job rather than one job per tree level.
func finalizeFromDeinit(_ finalize: @escaping @MainActor () -> Void) {
    if Thread.isMainThread, withUnsafeCurrentTask(body: { $0 != nil }) {
        // On the main thread and inside a task: the current task can only be
        // executing here if it is isolated to the main actor.
        MainActor.assumeIsolated(finalize)
    } else {
        Task { @MainActor in
            finalize()
        }
    }
}

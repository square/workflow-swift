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

/// Tracks re-entrancy into the workflow runtime's main-actor operations:
/// render passes, action application, and the output cascades they produce
/// (including any work Combine subscribers perform synchronously in
/// response).
///
/// Deinit finalization consults this to decide whether teardown may run
/// inline. A reference released while the runtime is mid-operation must not
/// tear down inline: observer callbacks, subject completions, and subtree
/// teardown would interleave with the in-flight operation that performed
/// the release.
@MainActor
enum WorkflowRuntimeActivity {
    private(set) static var depth = 0

    private static var pendingFinalizations: [@MainActor () -> Void] = []

    /// Runs `operation` with the runtime marked as active. Nesting is
    /// expected: event cascades re-enter through multiple entry points.
    /// When the outermost operation exits, finalizations deferred during it
    /// run immediately — still within the same runloop callout, so teardown
    /// timing stays at pre-deferral runloop granularity rather than slipping
    /// to a later main-queue drain.
    static func perform<T>(_ operation: () throws -> T) rethrows -> T {
        depth += 1
        defer {
            depth -= 1
            if depth == 0 {
                drainPendingFinalizations()
            }
        }
        return try operation()
    }

    /// Defers `finalize` until the outermost in-flight operation exits.
    /// Must only be called while the runtime is active (`depth > 0`).
    static func enqueueFinalization(_ finalize: @escaping @MainActor () -> Void) {
        pendingFinalizations.append(finalize)
    }

    private static func drainPendingFinalizations() {
        // A finalization can release references whose deinits enqueue more
        // finalizations (via a nested `perform`, drained there) or run
        // inline (depth is 0 here); loop until no stragglers remain.
        while !pendingFinalizations.isEmpty {
            let pending = pendingFinalizations
            pendingFinalizations.removeAll()
            for finalize in pending {
                finalize()
            }
        }
    }
}

/// Runs main-actor finalization work from a (nonisolated) `deinit`.
///
/// This exists because the natural tool — an `isolated deinit` (SE-0371) —
/// crashes the Swift 6.3.2 optimizer when compiling isolated deinits of
/// generic classes in release builds, and because isolated deinit's
/// dispatch rule (inline only from task contexts) doesn't match what
/// callers observe in practice: synchronous code that drops the last
/// reference to a workflow host expects teardown side effects (side-effect
/// terminations, observer callbacks) to have happened when the drop
/// returns, exactly as a plain inline `deinit` behaves.
///
/// So the rule here is based on what the runtime is doing rather than on
/// task context:
/// - On the main thread with the runtime quiescent, finalize inline —
///   teardown is synchronously observable, matching a plain `deinit`.
/// - If the runtime is mid-operation (the release happened during a render
///   pass or action cascade), defer until the outermost operation exits, so
///   teardown can't interleave with the in-flight operation but still
///   completes within the same runloop callout. Deferring to a `Task`
///   instead would push teardown to a later main-queue drain, which lets
///   unrelated main-queue work interleave with it and shifts the runloop
///   timing that snapshot tests and leak detectors observe.
/// - If the release happened off the main thread, hop onto the main actor.
///
/// A deferred finalization runs with the runtime quiescent, so the child
/// deinits it triggers finalize inline: an entire subtree tears down at a
/// single point rather than one deferral hop per tree level.
func finalizeFromDeinit(_ finalize: @escaping @MainActor () -> Void) {
    if Thread.isMainThread {
        // Dynamically safe: the main thread is the main actor's executor.
        MainActor.assumeIsolated {
            if WorkflowRuntimeActivity.depth == 0 {
                finalize()
            } else {
                WorkflowRuntimeActivity.enqueueFinalization(finalize)
            }
        }
    } else {
        Task { @MainActor in
            finalize()
        }
    }
}

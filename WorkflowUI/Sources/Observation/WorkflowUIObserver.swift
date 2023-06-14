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

#if canImport(UIKit)
import Foundation

/// Protocol to observe events emitted from WorkflowUI.
/// **N.B. This is currently part of an experimental interface, and may have breaking changes in the future.**
@_spi(ExperimentalObservation)
public protocol WorkflowUIObserver {
    func observeEvent<E: WorkflowUIEvent>(_ event: E)
}

// MARK: - Global Observation

@_spi(ExperimentalObservation)
public enum WorkflowUIObservation {
    /// The shared `WorkflowUIObserver` instance to which all `WorkflowUIEvent`s will be forwarded.
    public static var sharedUIObserver: WorkflowUIObserver?
}

#endif

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

import os.signpost

private extension OSLog {
    /// Logging will use this log handle when enabled
    static let workflow = OSLog(subsystem: "com.squareup.Workflow", category: "Workflow")

    /// The active log handle to use when logging. Defaults to the shared `.disabled` handle.
    static var active: OSLog = .disabled
}

// MARK: -

/// Namespace for specifying logging configuration data.
public enum WorkflowLogging {}

extension WorkflowLogging {
    public struct Config {
        /// Configuration options to control logging during a render pass.
        public enum RenderLoggingMode {
            /// No data will be recorded for WorkflowNode render timings.
            case none

            /// Render timings will only be recorded for root nodes in a Workflow tree.
            case rootsOnly

            /// Render timings will be recorded for all nodes in a Workflow tree.
            /// N.B. performance may be noticeably impacted when using this option.
            case allNodes
        }

        public var renderLoggingMode: RenderLoggingMode = .allNodes

        /// When `true`, the interval spanning a WorkflowNode's lifetime will be recorded.
        public var logLifetimes = true

        /// When `true`, action events will be recorded.
        public var logActions = true
    }

    /// Global setting to enable or disable logging.
    /// Note, this is independent of the specified `config` value, and simply governs whether
    /// the runtime should emit any logs.
    ///
    /// To enable logging, at a minimum you must set:
    /// `WorkflowLogging.enabled = true`
    ///
    /// If you wish for more control over what the runtime will log, you may additionally specify
    /// a custom value for `WorkflowLogging.config`.
    public static var enabled: Bool {
        get { OSLog.active === OSLog.workflow }
        set { OSLog.active = newValue ? .workflow : .disabled }
    }

    /// Configuration options used to determine which activities are logged.
    public static var config: Config = .rootRendersAndActions
}

extension WorkflowLogging.Config {
    /// Logging config that will output the most information.
    /// Will also have the most noticeable effect on performance.
    public static let debug: Self = .init(renderLoggingMode: .allNodes, logLifetimes: true, logActions: true)

    /// Logging config that will record render timings for root nodes as well as action events.
    /// This provides a reasonable performance tradeoff if you're interested in the runtime's behavior
    /// but don't wan to pay the price of logging everything.
    public static let rootRendersAndActions: Self = .init(renderLoggingMode: .rootsOnly, logLifetimes: false, logActions: true)
}

// MARK: -

/// Simple class that can be used to create signpost IDs based on an object pointer.
final class SignpostRef {
    init() {}
}

final class WorkflowLogger {
    // MARK: Workflows

    static func logWorkflowStarted<WorkflowType>(ref: WorkflowNode<WorkflowType>) {
        guard WorkflowLogging.config.logLifetimes else { return }

        let signpostID = OSSignpostID(log: .active, object: ref)
        os_signpost(
            .begin,
            log: .active,
            name: "Alive",
            signpostID: signpostID,
            "Workflow: %{public}@",
            String(describing: WorkflowType.self)
        )
    }

    static func logWorkflowFinished<WorkflowType>(ref: WorkflowNode<WorkflowType>) {
        guard WorkflowLogging.config.logLifetimes else { return }

        let signpostID = OSSignpostID(log: .active, object: ref)
        os_signpost(.end, log: .active, name: "Alive", signpostID: signpostID)
    }

    static func logSinkEvent<Action: WorkflowAction>(ref: AnyObject, action: Action) {
        guard WorkflowLogging.config.logActions else { return }

        let signpostID = OSSignpostID(log: .active, object: ref)
        os_signpost(
            .event,
            log: .active,
            name: "Sink Event",
            signpostID: signpostID,
            "Event for workflow: %{public}@",
            String(describing: Action.WorkflowType.self)
        )
    }

    // MARK: Rendering

    static func logWorkflowStartedRendering<WorkflowType>(
        ref: WorkflowNode<WorkflowType>,
        isRootNode: Bool
    ) {
        guard shouldLogRenderTimings(
            isRootNode: isRootNode
        ) else { return }

        let signpostID = OSSignpostID(log: .active, object: ref)
        os_signpost(
            .begin,
            log: .active,
            name: "Render",
            signpostID: signpostID,
            "Render Workflow: %{public}@",
            String(describing: WorkflowType.self)
        )
    }

    static func logWorkflowFinishedRendering<WorkflowType>(
        ref: WorkflowNode<WorkflowType>,
        isRootNode: Bool
    ) {
        guard shouldLogRenderTimings(
            isRootNode: isRootNode
        ) else { return }

        let signpostID = OSSignpostID(log: .active, object: ref)
        os_signpost(.end, log: .active, name: "Render", signpostID: signpostID)
    }

    // MARK: - Utilities

    private static func shouldLogRenderTimings(
        isRootNode: Bool
    ) -> Bool {
        switch WorkflowLogging.config.renderLoggingMode {
        case .none:
            return false
        case .rootsOnly:
            return isRootNode
        case .allNodes:
            return true
        }
    }
}

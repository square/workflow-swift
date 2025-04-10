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

import Foundation
import os.signpost

extension OSLog {
    /// Logging will use this log handle when enabled
    fileprivate static let workflow = OSLog(subsystem: "com.squareup.Workflow", category: "Workflow")

    /// The active log handle to use when logging. If `WorkflowLogging.osLoggingSupported` is
    /// `true`, defaults to the `workflow` handle, otherwise defaults to the shared `.disabled`
    /// handle.
    fileprivate static var active: OSLog = WorkflowLogging.isOSLoggingAllowed ? .workflow : .disabled
}

// MARK: -

/// Namespace for specifying logging configuration data.
public enum WorkflowLogging {}

extension WorkflowLogging {
    /// Flag indicating whether `OSLog` logs may be recorded. Note, actual emission of
    /// log statements in specific cases may depend on additional configuration options, so
    /// this being `true` does not necessarily imply logging will occur.
    @_spi(Logging)
    public static let isOSLoggingAllowed: Bool = {
        let env = ProcessInfo.processInfo.environment
        guard let value = env["com.squareup.workflow.allowOSLogging"] else {
            return false
        }
        return (value as NSString).boolValue
    }()
}

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
    /// Additionally, ``isOSLoggingAllowed`` must also be configured to be `true`.
    ///
    /// If you wish for more control over what the runtime will log, you may additionally specify
    /// a custom value for `WorkflowLogging.config`.
    public static var enabled: Bool {
        get { OSLog.active === OSLog.workflow }
        set {
            guard isOSLoggingAllowed else { return }
            OSLog.active = newValue ? .workflow : .disabled
        }
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

enum WorkflowLogger {
    // MARK: Workflows

    static func logWorkflowStarted<WorkflowType>(ref: WorkflowNode<WorkflowType>) {
        guard
            WorkflowLogging.isOSLoggingAllowed,
            WorkflowLogging.config.logLifetimes
        else { return }

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

    static func logWorkflowFinished(ref: WorkflowNode<some Any>) {
        guard
            WorkflowLogging.isOSLoggingAllowed,
            WorkflowLogging.config.logLifetimes
        else { return }

        let signpostID = OSSignpostID(log: .active, object: ref)
        os_signpost(.end, log: .active, name: "Alive", signpostID: signpostID)
    }

    static func logSinkEvent<Action: WorkflowAction>(ref: AnyObject, action: Action) {
        guard
            WorkflowLogging.isOSLoggingAllowed,
            WorkflowLogging.config.logActions
        else { return }

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
        ref: WorkflowNode<WorkflowType>
    ) {
        guard shouldLogRenderTimings(
            isRootNode: ref.isRootNode
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

    static func logWorkflowFinishedRendering(
        ref: WorkflowNode<some Any>
    ) {
        guard shouldLogRenderTimings(
            isRootNode: ref.isRootNode
        ) else { return }

        let signpostID = OSSignpostID(log: .active, object: ref)
        os_signpost(.end, log: .active, name: "Render", signpostID: signpostID)
    }

    // MARK: - Utilities

    private static func shouldLogRenderTimings(
        isRootNode: @autoclosure () -> Bool
    ) -> Bool {
        guard WorkflowLogging.isOSLoggingAllowed else {
            return false
        }
        switch WorkflowLogging.config.renderLoggingMode {
        case .none:
            return false
        case .rootsOnly:
            return isRootNode()
        case .allNodes:
            return true
        }
    }
}

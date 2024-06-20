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
@_spi(Logging) import Workflow

// Namespace for Worker logging
public enum WorkerLogging {}

extension WorkerLogging {
    public static var enabled: Bool {
        get { OSLog.active === OSLog.worker }
        set {
            guard WorkflowLogging.isOSLoggingAllowed else { return }
            OSLog.active = newValue ? .worker : .disabled
        }
    }
}

private extension OSLog {
    static let worker = OSLog(subsystem: "com.squareup.WorkflowReactiveSwift", category: "Worker")

    static var active: OSLog = {
        WorkflowLogging.isOSLoggingAllowed ? .worker : .disabled
    }()
}

// MARK: -

/// Logs Worker events to OSLog
final class WorkerLogger<WorkerType: Worker> {
    init() {}

    var signpostID: OSSignpostID { OSSignpostID(log: .active, object: self) }

    // MARK: - Workers

    func logStarted() {
        guard WorkerLogging.enabled else { return }

        os_signpost(
            .begin,
            log: .active,
            name: "Running",
            signpostID: signpostID,
            "Worker: %{private}@",
            String(describing: WorkerType.self)
        )
    }

    func logFinished(status: StaticString) {
        guard WorkerLogging.enabled else { return }

        os_signpost(.end, log: .active, name: "Running", signpostID: signpostID, status)
    }

    func logOutput() {
        guard WorkerLogging.enabled else { return }

        os_signpost(
            .event,
            log: .active,
            name: "Worker Event",
            signpostID: signpostID,
            "Event: %{private}@",
            String(describing: WorkerType.self)
        )
    }
}

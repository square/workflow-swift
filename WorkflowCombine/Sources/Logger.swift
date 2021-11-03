/*
 * Copyright 2021 Square Inc.
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
    static let worker = OSLog(subsystem: "com.squareup.WorkflowCombine", category: "Worker")
}

@available(iOS 13.0, macOS 10.15, *)
/// Logs Worker events to OSLog
final class WorkerLogger<WorkerType: Worker> {
    init() {}

    var signpostID: OSSignpostID { OSSignpostID(log: .worker, object: self) }

    // MARK: - Workers

    func logStarted() {
        os_signpost(
            .begin,
            log: .worker,
            name: "Running",
            signpostID: signpostID,
            "Worker: %{private}@",
            String(describing: WorkerType.self)
        )
    }

    func logFinished(status: StaticString) {
        os_signpost(
            .end,
            log: .worker,
            name: "Running",
            signpostID: signpostID,
            status
        )
    }

    func logOutput() {
        os_signpost(
            .event,
            log: .worker,
            name: "Worker Event",
            signpostID: signpostID,
            "Event: %{private}@",
            String(describing: WorkerType.self)
        )
    }
}

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

import Workflow
import XCTest

struct AppliedAction<WorkflowType: Workflow> {
    let erasedAction: Any

    init<ActionType: WorkflowAction>(_ action: ActionType) where ActionType.WorkflowType == WorkflowType {
        self.erasedAction = action
    }

    func assert<ActionType: WorkflowAction>(type: ActionType.Type = ActionType.self, file: StaticString, line: UInt, assertions: (ActionType) -> Void) where ActionType.WorkflowType == WorkflowType {
        guard let action = erasedAction as? ActionType else {
            XCTFail("Expected action of type \(ActionType.self), got \(erasedAction)", file: file, line: line)
            return
        }
        assertions(action)
    }
}

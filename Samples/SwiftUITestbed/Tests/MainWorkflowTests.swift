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
import WorkflowTesting
import XCTest

@testable import Development_SwiftUITestbed

class MainWorkflowTests: XCTestCase {
    func test_change_title() {
        SetterAction<MainWorkflow, String>
            .tester(withState: .init(title: ""))
            .verifyState {
                XCTAssertEqual($0.title, "")
            }
            .send(action: .set(\.title, to: "A"))
            .verifyState {
                XCTAssertEqual($0.title, "A")
            }
    }

    func test_get_all_caps() {
        SetterAction<MainWorkflow, String>
            .tester(withState: .init(title: ""))
            .verifyState {
                XCTAssert($0.isAllCaps)
            }
            .send(action: .set(\.title, to: "A"))
            .verifyState {
                XCTAssert($0.isAllCaps)
            }
            .send(action: .set(\.title, to: "!"))
            .verifyState {
                XCTAssert($0.isAllCaps)
            }
            .send(action: .set(\.title, to: "Ab"))
            .verifyState {
                XCTAssertFalse($0.isAllCaps)
            }
    }

    func test_set_all_caps() {
        SetterAction<MainWorkflow, Bool>
            .tester(withState: .init(title: "Abc!"))
            .send(action: .set(\.isAllCaps, to: true))
            .verifyState {
                XCTAssertEqual($0.title, "ABC!")
            }
            .send(action: .set(\.isAllCaps, to: false))
            .verifyState {
                XCTAssertEqual($0.title, "abc!")
            }
    }

    func test_no_close_button() {
        MainWorkflow(didClose: nil)
            .renderTester()
            .render {
                XCTAssertNil($0.didTapClose)
            }
    }

    func test_tap_close() {
        var hasCalledDidClose = false

        MainWorkflow(didClose: { hasCalledDidClose = true })
            .renderTester()
            .render {
                XCTAssertFalse(hasCalledDidClose)
                $0.didTapClose?()
                XCTAssert(hasCalledDidClose)
            }
    }

    func test_empty_title_toggle_disabled() {
        MainWorkflow(didClose: nil)
            .renderTester(initialState: .init(title: ""))
            .render {
                XCTAssertFalse($0.allCapsToggleIsEnabled)
            }
    }
}

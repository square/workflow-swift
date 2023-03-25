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

#if canImport(UIKit)

    import UIKit
    import XCTest
    @testable import WorkflowUI

    typealias Screen1 = ViewControllerTestFixture.Screen1
    typealias Screen2 = ViewControllerTestFixture.Screen2

    class UIViewControllerExtensionTests: XCTestCase {
        func test_update_viewNotLoaded() {
            let fixture = ViewControllerTestFixture(loadView: false, screen: Screen1(), environment: .empty)

            // Update to the same screen type should do nothing.

            XCTAssertFalse(fixture.root.isViewLoaded)
            XCTAssertFalse(fixture.root.content.isViewLoaded)

            fixture.root.update(with: Screen1(recordEvent: fixture.recordEvent), environment: .empty)
            XCTAssertFalse(fixture.root.isViewLoaded)
            XCTAssertFalse(fixture.root.content.isViewLoaded)
            XCTAssertEqual(fixture.events, [])

            // Update to a new screen type should swap out the screen and send the correct events.

            fixture.root.update(with: Screen2(recordEvent: fixture.recordEvent), environment: .empty)
            XCTAssertFalse(fixture.root.isViewLoaded)
            XCTAssertFalse(fixture.root.content.isViewLoaded)
            XCTAssertEqual(fixture.events, [
                .child_willMoveTo(identifier: "2", parent: fixture.root),
                .child_willMoveTo(identifier: "1", parent: nil),
                .child_didMoveTo(identifier: "2", parent: fixture.root),
                .child_didMoveTo(identifier: "1", parent: nil),
            ])
        }

        func test_update_viewLoaded() {
            let fixture = ViewControllerTestFixture(screen: Screen1(), environment: .empty)
            fixture.root.loadViewIfNeeded()

            // Update to the same screen type should do nothing.

            fixture.root.update(with: Screen1(recordEvent: fixture.recordEvent), environment: .empty)
            XCTAssertEqual(fixture.events, [])

            // Update to a new screen type should swap out the screen and send the correct events.

            fixture.root.update(with: Screen2(recordEvent: fixture.recordEvent), environment: .empty)
            XCTAssertEqual(fixture.events, [
                .child_willMoveTo(identifier: "2", parent: fixture.root),
                .child_willMoveTo(identifier: "1", parent: nil),
                .child_view_loadView(identifier: "2"),
                .child_didMoveTo(identifier: "2", parent: fixture.root),
                .child_didMoveTo(identifier: "1", parent: nil),
            ])
        }

        func test_update_hostedView() {
            let fixture = ViewControllerTestFixture(screen: Screen1(), environment: .empty)

            show(vc: fixture.root) { root in

                fixture.clearAllEvents()

                // Update to the same screen type should do nothing.

                root.update(with: Screen1(recordEvent: fixture.recordEvent), environment: .empty)
                XCTAssertEqual(fixture.events, [])

                // Update to a new screen type should swap out the screen and send the correct events.

                root.update(with: Screen2(recordEvent: fixture.recordEvent), environment: .empty)

                XCTAssertEqual(fixture.events, [
                    .child_willMoveTo(identifier: "2", parent: fixture.root),
                    .child_willMoveTo(identifier: "1", parent: nil),
                    .child_view_loadView(identifier: "2"),
                    .child_viewWillAppear(identifier: "2", animated: true),
                    .child_viewWillDisappear(identifier: "1", animated: true),
                    .child_viewDidAppear(identifier: "2", animated: true),
                    .child_viewDidDisappear(identifier: "1", animated: true),
                    .child_didMoveTo(identifier: "2", parent: fixture.root),
                    .child_didMoveTo(identifier: "1", parent: nil),
                ])
            }
        }
    }

#endif

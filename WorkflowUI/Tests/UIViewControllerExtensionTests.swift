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

    class UIViewControllerExtensionTests: XCTestCase {
        func test_update_viewNotLoaded() {
            let fixture = TestFixture(loadView: false, screen: Screen1(), environment: .empty)

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
            let fixture = TestFixture(screen: Screen1(), environment: .empty)
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
            let fixture = TestFixture(screen: Screen1(), environment: .empty)

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
                    .child_viewWillAppear(identifier: "2", animated: false),
                    .child_viewWillDisappear(identifier: "1", animated: false),
                    .child_viewDidAppear(identifier: "2", animated: false),
                    .child_viewDidDisappear(identifier: "1", animated: false),
                    .child_didMoveTo(identifier: "2", parent: fixture.root),
                    .child_didMoveTo(identifier: "1", parent: nil),
                ])
            }
        }
    }

    fileprivate enum TestingEvent: Equatable {
        // View Controller Events

        case child_viewWillAppear(identifier: String, animated: Bool)
        case child_viewWillDisappear(identifier: String, animated: Bool)
        case child_viewDidAppear(identifier: String, animated: Bool)
        case child_viewDidDisappear(identifier: String, animated: Bool)

        case child_willMoveTo(identifier: String, parent: UIViewController?)
        case child_didMoveTo(identifier: String, parent: UIViewController?)

        // View Events

        case child_view_loadView(identifier: String)
    }

    private final class RootVC: UIViewController {
        var content: VCBase

        init(screen: Screen, environment: ViewEnvironment) {
            self.content = screen
                .viewControllerDescription(environment: environment)
                .buildViewController() as! VCBase

            super.init(nibName: nil, bundle: nil)

            addChild(content)
            content.didMove(toParent: self)
        }

        required init?(coder: NSCoder) { fatalError() }

        override func loadView() {
            super.loadView()

            content.view.frame = view.bounds

            view.addSubview(content.view)
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()

            content.view.frame = view.bounds
        }

        func update(with screen: Screen, environment: ViewEnvironment) {
            update(child: \.content, with: screen.asAnyScreen(), in: environment)
        }
    }

    private struct Screen1: Screen {
        var recordEvent: (TestingEvent) -> Void = { _ in }

        func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
            ViewControllerDescription(
                type: VC1.self,
                build: { VC1(identifier: "1", recordEvent: recordEvent) },
                update: { $0.recordEvent = recordEvent }
            )
        }
    }

    private struct Screen2: Screen {
        var recordEvent: (TestingEvent) -> Void = { _ in }

        func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
            ViewControllerDescription(
                type: VC2.self,
                build: { VC2(identifier: "2", recordEvent: recordEvent) },
                update: { $0.recordEvent = recordEvent }
            )
        }
    }

    private final class TestFixture {
        public let root: RootVC

        private(set) var events: [TestingEvent] = []

        public func clearAllEvents() {
            events.removeAll()
        }

        public init(
            loadView: Bool = true,
            screen: Screen,
            environment: ViewEnvironment
        ) {
            self.root = .init(
                screen: screen,
                environment: environment
            )

            root.content.recordEvent = recordEvent

            if loadView {
                root.loadViewIfNeeded()
            }

            clearAllEvents()
        }

        var recordEvent: (TestingEvent) -> Void {
            { [weak self] in self?.events.append($0) }
        }
    }

    private final class VC1: VCBase {}
    private final class VC2: VCBase {}

    private class VCBase: UIViewController {
        let identifier: String

        var recordEvent: (TestingEvent) -> Void = { _ in }

        public init(
            identifier: String,
            recordEvent: @escaping (TestingEvent) -> Void
        ) {
            self.identifier = identifier
            self.recordEvent = recordEvent

            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override public func loadView() {
            super.loadView()

            recordEvent(.child_view_loadView(identifier: identifier))
        }

        override public func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            recordEvent(.child_viewWillAppear(identifier: identifier, animated: animated))

            /// Ensure that as we're appearing, our frame is the correct final size.

            XCTAssertEqual(view.bounds.size, parent?.view.bounds.size)
        }

        override public func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            recordEvent(.child_viewDidAppear(identifier: identifier, animated: animated))
        }

        override public func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            recordEvent(.child_viewWillDisappear(identifier: identifier, animated: animated))
        }

        override public func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            recordEvent(.child_viewDidDisappear(identifier: identifier, animated: animated))
        }

        override public func willMove(toParent parent: UIViewController?) {
            super.willMove(toParent: parent)
            recordEvent(.child_willMoveTo(identifier: identifier, parent: parent))
        }

        override public func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            recordEvent(.child_didMoveTo(identifier: identifier, parent: parent))
        }
    }

#endif

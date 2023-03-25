//
//  ViewControllerTextFixture.swift
//  WorkflowUI-Unit-Tests
//
//  Created by Kyle Van Essen on 10/18/22.
//

#if canImport(UIKit)

    import UIKit
    import WorkflowUI
    import XCTest

    final class ViewControllerTestFixture {
        let root: RootVC

        private(set) var events: [Event] = []

        func clearAllEvents() {
            events.removeAll()
        }

        init(
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

        var recordEvent: (Event) -> Void {
            { [weak self] in self?.events.append($0) }
        }
    }

    extension ViewControllerTestFixture {
        enum Event: Equatable {
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

        final class RootVC: UIViewController {
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

        struct Screen1: Screen {
            var recordEvent: (Event) -> Void = { _ in }

            func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
                ViewControllerDescription(
                    type: VC1.self,
                    build: { VC1(identifier: "1", recordEvent: recordEvent) },
                    update: { $0.recordEvent = recordEvent }
                )
            }
        }

        struct Screen2: Screen {
            var recordEvent: (Event) -> Void = { _ in }

            func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
                ViewControllerDescription(
                    type: VC2.self,
                    build: { VC2(identifier: "2", recordEvent: recordEvent) },
                    update: { $0.recordEvent = recordEvent }
                )
            }
        }

        final class VC1: VCBase {}
        final class VC2: VCBase {}

        class VCBase: UIViewController {
            let identifier: String

            var recordEvent: (Event) -> Void = { _ in }

            public init(
                identifier: String,
                recordEvent: @escaping (Event) -> Void
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
    }

#endif

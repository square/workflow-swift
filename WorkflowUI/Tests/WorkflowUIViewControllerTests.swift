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
import Workflow
import XCTest

@testable @_spi(ExperimentalObservation) import WorkflowUI

final class WorkflowUIViewControllerTests: WorkflowUIObservationTestCase {
    // MARK: Event Emission

    func test_viewWillAppear_emitsEvent() throws {
        let subject = WorkflowUIViewController()

        let observedEvents = observationEvents(from: subject) {
            subject.viewWillAppear(false)
        }

        let appearanceEvent = try XCTUnwrap(observedEvents.first as? ViewWillAppearEvent)
        XCTAssertEqual(appearanceEvent.viewController, subject)
        XCTAssertFalse(appearanceEvent.animated)
        XCTAssertTrue(appearanceEvent.isFirstAppearance)
    }

    func test_viewDidAppear_emitsEvent() throws {
        let subject = WorkflowUIViewController()

        let observedEvents = observationEvents(from: subject) {
            subject.viewDidAppear(false)
        }

        let appearanceEvent = try XCTUnwrap(observedEvents.first as? ViewDidAppearEvent)
        XCTAssertEqual(appearanceEvent.viewController, subject)
        XCTAssertFalse(appearanceEvent.animated)
        XCTAssertTrue(appearanceEvent.isFirstAppearance)
    }

    func test_viewWillDisappear_emitsEvent() throws {
        let subject = WorkflowUIViewController()

        let observedEvents = observationEvents(from: subject) {
            subject.viewWillDisappear(false)
        }

        let appearanceEvent = try XCTUnwrap(observedEvents.first as? ViewWillDisappearEvent)
        XCTAssertEqual(appearanceEvent.viewController, subject)
        XCTAssertFalse(appearanceEvent.animated)
    }

    func test_viewDidDisappear_emitsEvent() throws {
        let subject = WorkflowUIViewController()

        let observedEvents = observationEvents(from: subject) {
            subject.viewDidDisappear(false)
        }

        let appearanceEvent = try XCTUnwrap(observedEvents.first as? ViewDidDisappearEvent)
        XCTAssertEqual(appearanceEvent.viewController, subject)
        XCTAssertFalse(appearanceEvent.animated)
    }

    func test_viewWillLayoutSubviews_emitsEvent() throws {
        let subject = WorkflowUIViewController()

        let observedEvents = observationEvents(from: subject) {
            subject.viewWillLayoutSubviews()
        }

        let appearanceEvent = try XCTUnwrap(observedEvents.first as? ViewWillLayoutSubviewsEvent)
        XCTAssertEqual(appearanceEvent.viewController, subject)
    }

    func test_viewDidLayoutSubviews_emitsEvent() throws {
        let subject = WorkflowUIViewController()

        let observedEvents = observationEvents(from: subject) {
            subject.viewDidLayoutSubviews()
        }

        let appearanceEvent = try XCTUnwrap(observedEvents.first as? ViewDidLayoutSubviewsEvent)
        XCTAssertEqual(appearanceEvent.viewController, subject)
    }

    // MARK: -

    func test_hasViewAppeared_onlySetAfterFirstAppearance() throws {
        let subject = WorkflowUIViewController()

        XCTAssertFalse(subject.hasViewAppeared)

        subject.viewWillAppear(true)

        XCTAssertFalse(subject.hasViewAppeared)

        subject.viewDidAppear(true)

        XCTAssertTrue(subject.hasViewAppeared)

        // simulate another appearance
        subject.viewWillAppear(false)
        subject.viewDidAppear(false)

        guard observedEvents.count == 4 else {
            XCTFail("Expected 4 events, got \(observedEvents.count)")
            return
        }

        let firstWillAppearEvent = try XCTUnwrap(observedEvents[0] as? ViewWillAppearEvent)
        XCTAssertEqual(
            firstWillAppearEvent,
            ViewWillAppearEvent(
                viewController: subject,
                animated: true,
                isFirstAppearance: true
            )
        )

        let firstDidAppearEvent = try XCTUnwrap(observedEvents[1] as? ViewDidAppearEvent)
        XCTAssertEqual(
            firstDidAppearEvent,
            ViewDidAppearEvent(
                viewController: subject,
                animated: true,
                isFirstAppearance: true
            )
        )

        let secondWillAppearEvent = try XCTUnwrap(observedEvents[2] as? ViewWillAppearEvent)
        XCTAssertEqual(
            secondWillAppearEvent,
            ViewWillAppearEvent(
                viewController: subject,
                animated: false,
                isFirstAppearance: false
            )
        )

        let secondDidAppearEvent = try XCTUnwrap(observedEvents[3] as? ViewDidAppearEvent)
        XCTAssertEqual(
            secondDidAppearEvent,
            ViewDidAppearEvent(
                viewController: subject,
                animated: false,
                isFirstAppearance: false
            )
        )
    }
}

// MARK: Known Subclass Tests

final class WorkflowUIViewControllerSubclassesTests: WorkflowUIObservationTestCase {
    // MARK: Subclass Tests

    func test_describedVC_emitsVCLifecycleEvents() {
        let subject = DescribedViewController(description: .testing)

        let observedEvents = observationEvents(from: subject) {
            subject.viewWillAppear(false)
            subject.viewDidAppear(false)

            subject.viewWillLayoutSubviews()
            subject.viewDidLayoutSubviews()
        }

        let expectedEventDescriptors: [EventDescriptor] = [
            .viewWillAppear,
            .viewDidAppear,
            .viewWillLayoutSubviews,
            .viewDidLayoutSubviews,
        ]

        XCTAssertEqual(
            observedEvents.map(\.descriptor),
            expectedEventDescriptors
        )
    }

    func test_screenVC_emitsVCLifecycleEvents() {
        let subject = ScreenViewController(screen: TestScreen(), environment: .empty)

        let observedEvents = observationEvents(from: subject) {
            subject.viewWillAppear(false)
            subject.viewDidAppear(false)

            subject.viewWillLayoutSubviews()
            subject.viewDidLayoutSubviews()
        }

        let expectedEventDescriptors: [EventDescriptor] = [
            .viewWillAppear,
            .viewDidAppear,
            .viewWillLayoutSubviews,
            .viewDidLayoutSubviews,
        ]

        XCTAssertEqual(
            observedEvents.map(\.descriptor),
            expectedEventDescriptors
        )
    }

    func test_hostingController_emitsVCLifecycleEvents() {
        let subject = WorkflowHostingController(workflow: TestWorkflow())

        let observedEvents = observationEvents(from: subject) {
            subject.viewWillAppear(false)
            subject.viewDidAppear(false)

            subject.viewWillLayoutSubviews()
            subject.viewDidLayoutSubviews()
        }

        let expectedEventDescriptors: [EventDescriptor] = [
            .viewWillAppear,
            .viewDidAppear,
            .viewWillLayoutSubviews,
            .viewDidLayoutSubviews,
        ]

        XCTAssertEqual(
            observedEvents.map(\.descriptor),
            expectedEventDescriptors
        )
    }
}

private struct TestWorkflow: Workflow {
    func makeInitialState() -> Int { 0 }

    func render(state: Int, context: RenderContext<TestWorkflow>) -> TestScreen {
        TestScreen(value: state)
    }
}

private struct TestScreen: Screen {
    var value: Int = 0

    func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
        .testing
    }
}

extension ViewControllerDescription {
    fileprivate static var testing: Self {
        .init(
            environment: .empty,
            build: { UIViewController() },
            update: { _ in }
        )
    }
}
#endif

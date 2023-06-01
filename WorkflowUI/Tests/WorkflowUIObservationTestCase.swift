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

import Combine
import Workflow
@_spi(WorkflowUIGlobalObservation) import WorkflowUI
import XCTest

open class WorkflowUIObservationTestCase: XCTestCase {
    var testUIObserver: TestUIObserver!

    var uiEventPublisher: AnyPublisher<WorkflowUIEvent, Never>!
    private var publishingObserver: PublishingObserver!

    override open func invokeTest() {
        testUIObserver = TestUIObserver()
        publishingObserver = PublishingObserver()
        defer {
            testUIObserver = nil
            publishingObserver = nil
        }

        withGlobalObserver(publishingObserver) {
            super.invokeTest()
        }
    }

    private func withGlobalObserver(_ globalObserver: WorkflowUIObserver, perform: () -> Void) {
        let oldObserver = WorkflowUIObservation.sharedUIObserver
        defer {
            WorkflowUIObservation.sharedUIObserver = oldObserver
        }

        WorkflowUIObservation.sharedUIObserver = globalObserver
        perform()
    }

    func observationEvents(
        from viewController: WorkflowUIViewController,
        perform: () -> Void
    ) -> [WorkflowUIEvent] {
        var events: [WorkflowUIEvent] = []

        let scoped = publishingObserver
            .publisher
            .filter { $0.viewController === viewController }
            .sink { events.append($0) }
        defer { scoped.cancel() }

        perform()

        return events
    }
}

final class PublishingObserver: WorkflowUIObserver {
    let subject: PassthroughSubject<WorkflowUIEvent, Never>
    private(set) lazy var publisher = { subject.eraseToAnyPublisher() }()

    init() {
        self.subject = .init()
    }

    func observeEvent<E: WorkflowUIEvent>(_ event: E) {
        subject.send(event)
    }
}

final class TestUIObserver: WorkflowUIObserver {
    var recordedEvents: [WorkflowUIEvent] = []

    var eventFilter: (WorkflowUIEvent) -> Bool

    var recordedEventDescriptors: [String] {
        func getStaticType<E: WorkflowUIEvent>(_ event: E) -> String {
            "\(E.self)"
        }
        return recordedEvents.map { event in
            getStaticType(event)
        }
    }

    init(
        eventFilter: @escaping (WorkflowUIEvent) -> Bool = { _ in true }
    ) {
        self.eventFilter = eventFilter
    }

    func observeEvent<E: WorkflowUIEvent>(_ event: E) {
        guard eventFilter(event) else { return }
        recordedEvents.append(event)
    }
}

// MARK: Event Introspection Utilities

typealias EventDescriptor = String
extension EventDescriptor {
    // MARK: ViewController lifecycle events

    static var viewWillAppear: EventDescriptor = "\(ViewWillAppearEvent.self)"

    static var viewDidAppear: EventDescriptor = "\(ViewDidAppearEvent.self)"

    static var viewWillLayoutSubviews: EventDescriptor = "\(ViewWillLayoutSubviewsEvent.self)"

    static var viewDidLayoutSubviews: EventDescriptor = "\(ViewDidLayoutSubviewsEvent.self)"

    // MARK: DescribedViewController Events

    static var describedViewControllerDidUpdate: EventDescriptor =
        "\(DescribedViewControllerDidUpdate.self)"

    // MARK: ScreenViewController Events

    static func screenDidChange<S: Screen>(
        _ screenType: S.Type
    ) -> EventDescriptor {
        "\(ScreenDidChangeEvent<S>.self)"
    }

    // MARK: WorkflowHostingController Events

    static func hostingControllerDidUpdate<W: Workflow>(
        _ workflowType: W.Type
    ) -> EventDescriptor where W.Rendering: Screen {
        "\(WorkflowHostingControllerDidUpdate<W.Rendering, W.Output>.self)"
    }

    static func fromEvent(_ event: WorkflowUIEvent) -> EventDescriptor {
        func staticTypeDescriptor<E: WorkflowUIEvent>(_ event: E) -> EventDescriptor {
            "\(E.self)"
        }

        return staticTypeDescriptor(event)
    }
}

extension WorkflowUIEvent {
    var descriptor: EventDescriptor {
        EventDescriptor.fromEvent(self)
    }
}

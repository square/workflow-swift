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
@_spi(ExperimentalObservation) import WorkflowUI
import XCTest

open class WorkflowUIObservationTestCase: XCTestCase {
    var publishingObserver: PublishingObserver!

    var observedEvents: [WorkflowUIEvent] = []

    private var cancellables: [AnyCancellable] = []

    override open func invokeTest() {
        publishingObserver = PublishingObserver()
        defer { publishingObserver = nil }

        // collect all events emitted during test invocation
        publishingObserver.subject
            .sink { [weak self] event in
                self?.observedEvents.append(event)
            }
            .store(in: &cancellables)

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

        let scopedObserver = publishingObserver
            .publisher
            .filter { $0.viewController === viewController }
            .sink { events.append($0) }
        defer { scopedObserver.cancel() }

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

// MARK: Event Introspection Utilities

typealias EventDescriptor = String
extension EventDescriptor {
    static var viewWillAppear: EventDescriptor = "\(ViewWillAppearEvent.self)"

    static var viewDidAppear: EventDescriptor = "\(ViewDidAppearEvent.self)"

    static var viewWillLayoutSubviews: EventDescriptor = "\(ViewWillLayoutSubviewsEvent.self)"

    static var viewDidLayoutSubviews: EventDescriptor = "\(ViewDidLayoutSubviewsEvent.self)"
}

extension WorkflowUIEvent {
    var descriptor: EventDescriptor {
        "\(type(of: self))"
    }
}

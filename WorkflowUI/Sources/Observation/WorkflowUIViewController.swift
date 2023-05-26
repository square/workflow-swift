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
import Foundation
import UIKit

// TODO: contrast subclassing with protocol composition
// public protocol ObservationEventEmitter {
//    func sendObservationEvent<E: WorkflowUIEvent>(_ event: E)
// }

@propertyWrapper
public struct GlobalUIObservable {
    private var _localObserver: WorkflowUIObserver?
    public var wrappedValue: WorkflowUIObserver? {
        get { _localObserver }
        set {
            _localObserver = WorkflowUIObservation
                .sharedObserversInterceptor
                .workflowUIObservers(for: newValue)
        }
    }

    public init(observer: WorkflowUIObserver? = nil) {
        self._localObserver = observer
    }
}

/// Ancestor type from which all ViewControllers in WorkflowUI inherit.
open class WorkflowUIViewController: UIViewController {
    @GlobalUIObservable
    public var observer: WorkflowUIObserver?

    // MARK: Event Emission

    public final func sendObservationEvent<E: WorkflowUIEvent>(
        _ event: @autoclosure () -> E
    ) {
        observer?.observeEvent(event())
    }

    // MARK: Lifecycle Methods

    override open func viewWillAppear(_ animated: Bool) {
        sendObservationEvent(ViewControllerEvents.ViewWillAppear(
            viewController: self,
            animated: animated
        ))
        super.viewWillAppear(animated)
    }

    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        sendObservationEvent(ViewControllerEvents.ViewDidAppear(
            viewController: self,
            animated: animated
        ))
    }

    override open func viewWillLayoutSubviews() {
        // no need to call super since it does nothing
        sendObservationEvent(
            ViewControllerEvents.WillLayoutSubviews(viewController: self)
        )
    }

    override open func viewDidLayoutSubviews() {
        // no need to call super since it does nothing
        sendObservationEvent(
            ViewControllerEvents.DidLayoutSubviews(viewController: self)
        )
    }
}
#endif

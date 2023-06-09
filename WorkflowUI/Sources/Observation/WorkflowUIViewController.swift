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

/// Ancestor type from which all ViewControllers in WorkflowUI inherit.
open class WorkflowUIViewController: UIViewController {
    /// Set to `true` once `viewDidAppear` has been called
    public private(set) final var hasViewAppeared: Bool = false

    // MARK: Event Emission

    @_spi(ExperimentalObservation)
    public final func sendObservationEvent<E: WorkflowUIEvent>(
        _ event: @autoclosure () -> E
    ) {
        WorkflowUIObservation
            .sharedUIObserver?
            .observeEvent(event())
    }

    // MARK: Lifecycle Methods

    override open func viewWillAppear(_ animated: Bool) {
        sendObservationEvent(ViewWillAppearEvent(
            viewController: self,
            animated: animated,
            isFirstAppearance: !hasViewAppeared
        ))
        super.viewWillAppear(animated)
    }

    override open func viewDidAppear(_ animated: Bool) {
        let isFirstAppearance = !hasViewAppeared
        hasViewAppeared = true

        super.viewDidAppear(animated)

        sendObservationEvent(ViewDidAppearEvent(
            viewController: self,
            animated: animated,
            isFirstAppearance: isFirstAppearance
        ))
    }

    override open func viewWillLayoutSubviews() {
        // no need to call super since it does nothing
        sendObservationEvent(
            ViewWillLayoutSubviewsEvent(viewController: self)
        )
    }

    override open func viewDidLayoutSubviews() {
        // no need to call super since it does nothing
        sendObservationEvent(
            ViewDidLayoutSubviewsEvent(viewController: self)
        )
    }
}
#endif

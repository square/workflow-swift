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

@_spi(ExperimentalObservation)
public protocol WorkflowUIEvent {
    var viewController: UIViewController { get }
}

// MARK: ViewController Lifecycle Events

@_spi(ExperimentalObservation)
public struct ViewWillLayoutSubviewsEvent: WorkflowUIEvent, Equatable {
    public let viewController: UIViewController
}

@_spi(ExperimentalObservation)
public struct ViewDidLayoutSubviewsEvent: WorkflowUIEvent, Equatable {
    public let viewController: UIViewController
}

@_spi(ExperimentalObservation)
public struct ViewWillAppearEvent: WorkflowUIEvent, Equatable {
    public let viewController: UIViewController
    public let animated: Bool
    public let isFirstAppearance: Bool
}

@_spi(ExperimentalObservation)
public struct ViewDidAppearEvent: WorkflowUIEvent, Equatable {
    public let viewController: UIViewController
    public let animated: Bool
    public let isFirstAppearance: Bool
}
#endif

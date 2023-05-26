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

public protocol WorkflowUIEvent {}

public protocol ViewControllerEvent: WorkflowUIEvent {
    var viewController: UIViewController { get }
}

// MARK: ViewController Events

public enum ViewControllerEvents {
    public struct WillLayoutSubviews: ViewControllerEvent {
        public let viewController: UIViewController
    }

    public struct DidLayoutSubviews: ViewControllerEvent {
        public let viewController: UIViewController
    }

    public struct ViewWillAppear: ViewControllerEvent {
        public let viewController: UIViewController
        public let animated: Bool
    }

    public struct ViewDidAppear: ViewControllerEvent {
        public let viewController: UIViewController
        public let animated: Bool
    }
}
#endif

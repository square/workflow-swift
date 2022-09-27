/*
 * Copyright 2021 Square Inc.
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

    ///
    ///
    public struct AnyContentScreen: Screen {
        public var transition: ViewTransition
        public let content: AnyScreen

        public init<ScreenType: Screen>(
            transition: ViewTransition = .fade(),
            content: () -> ScreenType
        ) {
            let content = content()

            if let content = content as? Self {
                self = content
            } else {
                self.content = content.asAnyScreen()
            }

            self.transition = transition
        }

        // MARK: Screen

        public func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
            let description = content.viewControllerDescription(environment: environment)

            return ViewControllerDescription(
                /// The inner `DescribedViewController` will respect `performInitialUpdate` from
                /// the nested screen – so our value should always be false.
                performInitialUpdate: false,
                transition: transition,
                type: DescribedViewController.self,
                build: {
                    DescribedViewController(description: description)
                },
                update: { vc in
                    vc.update(description: description, animated: true)
                }
            )
        }
    }

#endif

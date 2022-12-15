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

#if DEBUG && canImport(UIKit) && canImport(WorkflowUI)

    import WorkflowUI
    import XCTest

    /// Used as the stand-in value returned by RenderTester when an AnyScreen is expected but not provided
    struct RenderTesterPlaceholderScreen: Screen {
        func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
            ViewControllerDescription(
                type: UIViewController.self,
                build: {
                    XCTFail("Unexpected construction of screen in RenderTester")
                    return UIViewController()
                },
                update: { _ in }
            )
        }
    }

#endif

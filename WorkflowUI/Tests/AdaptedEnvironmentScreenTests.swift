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

import UIKit
import XCTest
@testable import WorkflowUI

class AdaptedEnvironmentScreenTests: XCTestCase {
    func test_wrapping() {
        var environment: ViewEnvironment = .empty

        let screen = TestScreen { environment = $0 }
            .adaptedEnvironment(key: TestingKey1.self, value: "adapted1.1")
            .adaptedEnvironment(key: TestingKey1.self, value: "adapted1.2")
            .adaptedEnvironment(key: TestingKey2.self, value: "adapted2.1")
            .adaptedEnvironment(key: TestingKey1.self, value: "adapted1.3")
            .adaptedEnvironment(key: TestingKey2.self, value: "adapted2.2")

        _ = screen.viewControllerDescription(environment: .empty)

        // The inner-most change; the one closest to the screen; should be the value we get.
        XCTAssertEqual(environment[TestingKey1.self], "adapted1.1")
        XCTAssertEqual(environment[TestingKey2.self], "adapted2.1")
    }
}

fileprivate enum TestingKey1: ViewEnvironmentKey {
    static let defaultValue: String? = nil
}

fileprivate enum TestingKey2: ViewEnvironmentKey {
    static let defaultValue: String? = nil
}

fileprivate struct TestScreen: Screen {
    var read: (ViewEnvironment) -> Void

    func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
        read(environment)

        return ViewController.description(for: self, environment: environment)
    }

    private class ViewController: ScreenViewController<TestScreen> {}
}

#endif

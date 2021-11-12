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

    import XCTest

    @testable import WorkflowUI

    class ViewEnvironmentTests: XCTestCase {
        func test_environment() {
            let environmentScreen = EmptyScreen()
                .environment(\.testInteger, 42)

            var environment = ViewEnvironment.empty

            XCTAssertNotEqual(environment.testInteger, 42)
            environmentScreen.transform(&environment)
            XCTAssertEqual(environment.testInteger, 42)
        }

        func test_transformEnvironment_keyPath() {
            let environmentScreen = EmptyScreen()
                .transformEnvironment(\.testString) { value in
                    value += ", world"
                }

            var environment = ViewEnvironment.empty
            environment.testString = "Hello"

            XCTAssertEqual(environment.testString, "Hello")
            environmentScreen.transform(&environment)
            XCTAssertEqual(environment.testString, "Hello, world")
        }

        func test_transformEnvironment() {
            let environmentScreen = EmptyScreen()
                .transformEnvironment { environment in
                    environment.testString = String(environment.testString.reversed())
                    environment.testInteger *= 2
                }

            var environment = ViewEnvironment.empty
            environment.testString = "Goodbye"
            environment.testInteger = 431

            XCTAssertEqual(environment.testString, "Goodbye")
            XCTAssertEqual(environment.testInteger, 431)
            environmentScreen.transform(&environment)
            XCTAssertEqual(environment.testString, "eybdooG")
            XCTAssertEqual(environment.testInteger, 862)
        }

        func test_appliesToContainedScreen() {
            var receivedEnvironment: ViewEnvironment?

            let screen = EnvironmentReportingScreen(
                onEnvironment: { receivedEnvironment = $0 }
            ).environment(\.testInteger, 87)

            XCTAssertNil(receivedEnvironment)
            _ = screen.viewControllerDescription(environment: .empty)
            XCTAssertEqual(receivedEnvironment?.testInteger, 87)
        }
    }

    fileprivate enum TestIntegerEnvironmentKey: ViewEnvironmentKey {
        static var defaultValue: Int = 0
    }

    fileprivate enum TestStringEnvironmentKey: ViewEnvironmentKey {
        static var defaultValue: String = ""
    }

    extension ViewEnvironment {
        fileprivate var testInteger: Int {
            get { self[TestIntegerEnvironmentKey.self] }
            set { self[TestIntegerEnvironmentKey.self] = newValue }
        }

        fileprivate var testString: String {
            get { self[TestStringEnvironmentKey.self] }
            set { self[TestStringEnvironmentKey.self] = newValue }
        }
    }

    fileprivate struct EmptyScreen: Screen {
        func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
            return ViewControllerDescription(build: { UIViewController() }, update: { _ in })
        }
    }

    fileprivate struct EnvironmentReportingScreen: Screen {
        var onEnvironment: (ViewEnvironment) -> Void

        func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
            onEnvironment(environment)
            return ViewControllerDescription(build: { UIViewController() }, update: { _ in })
        }
    }

#endif

//
//  ViewEnvironmentTests.swift
//  Development-Unit-WorkflowUITests
//
//  Created by Dhaval Shreyas on 4/28/21.
//

import Foundation

#if canImport(UIKit)

    import XCTest

    import ReactiveSwift
    import Workflow
    @testable import WorkflowUI

    class ViewEnvironmentTests: XCTestCase {
        func test_defaultValue_hasExpectedValue() {
            let viewEnvironment = ViewEnvironment.empty
            XCTAssert(viewEnvironment[TestKey.self] == 1000)
        }

        func test_setAndGet_returnsSameValue() {
            var viewEnvironment = ViewEnvironment.empty
            viewEnvironment[TestKey.self] = 10
            XCTAssert(viewEnvironment[TestKey.self] == 10)
        }

        func test_overwritingKey_returnsUpdatedValue() {
            var viewEnvironment = ViewEnvironment.empty
            viewEnvironment[TestKey.self] = 10
            viewEnvironment[TestKey.self] = 20
            XCTAssert(viewEnvironment[TestKey.self] == 20)
        }

        func test_comparingEmptyViewEnvironment_returnsTrue() {
            XCTAssert(ViewEnvironment.empty == ViewEnvironment.empty)
        }

        func test_comparingEqualViewEnvironments_returnsTrue() {
            var viewEnvironmentA = ViewEnvironment.empty
            var viewEnvironmentB = ViewEnvironment.empty

            viewEnvironmentA[TestKey.self] = 10
            viewEnvironmentB[TestKey.self] = 10

            XCTAssert(viewEnvironmentA == viewEnvironmentB)
        }

        func test_comparingUnequalViewEnvironments_returnsFalse() {
            var viewEnvironmentA = ViewEnvironment.empty
            var viewEnvironmentB = ViewEnvironment.empty

            viewEnvironmentA[TestKey.self] = 10
            viewEnvironmentB[TestKey.self] = 20

            XCTAssert(viewEnvironmentA != viewEnvironmentB)
        }
    }

    private enum TestKey: ViewEnvironmentKey {
        typealias Value = Int
        static var defaultValue: Int { 1000 }
    }

#endif

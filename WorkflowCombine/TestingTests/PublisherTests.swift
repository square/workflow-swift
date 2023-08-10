//
//  PublisherTests.swift
//  WorkflowCombine
//
//  Created by Soo Rin Park on 11/3/21.
//

import Combine
import Foundation
import Workflow
import WorkflowTesting
import XCTest
@testable import WorkflowCombineTesting

class PublisherTests: XCTestCase {
    func testPublisherWorkflow() {
        TestWorkflow()
            .renderTester()
            .expect(
                publisher: Publishers.Sequence<[Int], Never>.self,
                producingOutput: 1,
                key: "123"
            )
            .render {}
    }

    func test_publisher_no_output() {
        TestWorkflow()
            .renderTester()
            .expect(
                publisher: Publishers.Sequence<[Int], Never>.self,
                producingOutput: nil,
                key: "123"
            )
            .render {}
            .assertNoAction()
    }

    struct TestWorkflow: Workflow {
        typealias State = Void
        typealias Rendering = Void

        func render(state: State, context: RenderContext<Self>) -> Rendering {
            [1].publisher
                .mapOutput { _ in AnyWorkflowAction<TestWorkflow>.noAction }
                .running(in: context, key: "123")
        }
    }
}

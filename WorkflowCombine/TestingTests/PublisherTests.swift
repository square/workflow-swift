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

@available(iOS 13.0, macOS 10.15, *)
class PublisherTests: XCTestCase {
    func testPublisherWorkflow() {
        TestWorkflow()
            .renderTester()
            .expect(publisher: Publishers.Sequence<[Int], Never>.self, output: 1, key: "123")
            .render {}
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

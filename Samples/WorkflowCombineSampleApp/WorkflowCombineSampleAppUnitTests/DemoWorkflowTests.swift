//
//  DemoWorkflowTests.swift
//  WorkflowCombineSampleAppUnitTests
//
//  Created by Soo Rin Park on 11/1/21.
//

import Combine
import Workflow
import WorkflowTesting
import XCTest
@testable import Development_WorkflowCombineSampleApp

class DemoWorkflowTests: XCTestCase {
    func test_workflowIsRenderedEverySecondForFiveSeconds() {
        let expectedDate = Date(timeIntervalSince1970: 0)

        DemoWorkflow
            .Action
            .tester(withState: .init(date: Date())) // the initial date itself does not matter
            .send(action: .init(publishedDate: expectedDate))
            .assert(state: .init(date: expectedDate))
    }
}

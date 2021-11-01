//
//  WorkflowCombineSampleAppUnitTests.swift
//  WorkflowCombineSampleAppUnitTests
//
//  Created by Soo Rin Park on 11/1/21.
//

import Combine
import Workflow
import XCTest
@testable import Development_WorkflowCombineSampleApp

class DemoWorkerTests: XCTestCase {
    func test_workflowIsRenderedEverySecondForFiveSeconds() {
        let host = WorkflowHost(workflow: DemoWorkflow())

        let expectation = XCTestExpectation(description: "host rendering is updated every second")
        expectation.expectedFulfillmentCount = 5
        let disposable = host.rendering.signal.observeValues { rendering in
            print(rendering)
            expectation.fulfill()
        }

        // buffer milisecond is added to account for the workflow to start running
        wait(for: [expectation], timeout: 5.1)
        disposable?.dispose()
    }
}

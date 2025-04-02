import XCTest

@testable import Workflow

final class HostContextTests: XCTestCase {
    func test_conditional_debug_info_no_debugger() {
        let subject = HostContext.testing(debugger: nil)
        subject.ifDebuggerEnabled {
            XCTFail("should not be called")
        }
    }

    func test_conditional_debug_info_with_debugger() {
        let subject = HostContext.testing(debugger: TestDebugger())
        let expectation = expectation(description: "debugger block invoked")

        subject.ifDebuggerEnabled {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 0.001)
    }
}

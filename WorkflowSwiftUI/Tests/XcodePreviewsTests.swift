#if DEBUG

import XCTest
@testable import WorkflowSwiftUI

final class XcodePreviewsTests: XCTestCase {
    func test_isRunning_whenXcodeSetsThePreviewFlag() {
        XCTAssertTrue(XcodePreviews.isRunning(in: ["XCODE_RUNNING_FOR_PREVIEWS": "1"]))
    }

    func test_isRunning_whenTheFlagIsAbsent() {
        XCTAssertFalse(XcodePreviews.isRunning(in: [:]))
        XCTAssertFalse(XcodePreviews.isRunning(in: ["XCODE_RUNNING_FOR_PREVIEWS_EXTRA": "1"]))
    }

    /// Xcode sets the flag to exactly `"1"`. Anything else is not the canvas, and treating a
    /// truthy-looking value as one would silence the check outside of previews.
    func test_isRunning_whenTheFlagIsNotOne() {
        XCTAssertFalse(XcodePreviews.isRunning(in: ["XCODE_RUNNING_FOR_PREVIEWS": "0"]))
        XCTAssertFalse(XcodePreviews.isRunning(in: ["XCODE_RUNNING_FOR_PREVIEWS": ""]))
        XCTAssertFalse(XcodePreviews.isRunning(in: ["XCODE_RUNNING_FOR_PREVIEWS": "YES"]))
        XCTAssertFalse(XcodePreviews.isRunning(in: ["XCODE_RUNNING_FOR_PREVIEWS": "true"]))
    }

    /// The suite itself is not the preview canvas, so the process-wide value must be `false`.
    /// Without this, a `true` reading would silently disable
    /// `test_perceptionRuntimeWarningsWhenUsingObservation`, whose assertion is the *absence* of a
    /// Perception failure.
    func test_isRunning_isFalseInTheTestProcess() {
        XCTAssertFalse(XcodePreviews.isRunning)
    }
}

#endif

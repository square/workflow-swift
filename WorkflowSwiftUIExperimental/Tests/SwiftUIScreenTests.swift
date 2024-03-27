import SwiftUI
import UIKit
import WorkflowSwiftUIExperimental
import XCTest

final class SwiftUIScreenTests: XCTestCase {
    override func setUp() {
        contentScreenSizingOptions = []
    }

    func test_preferredContentSize_noSizingOptions() {
        contentScreenSizingOptions = []

        let viewController = ContentScreen()
            .buildViewController(in: .empty)

        viewController.view.layoutIfNeeded()

        XCTAssertEqual(viewController.preferredContentSize, .zero)
    }

    func test_preferredContentSize() {
        contentScreenSizingOptions = .preferredContentSize

        let viewController = ContentScreen()
            .buildViewController(in: .empty)

        viewController.view.layoutIfNeeded()

        XCTAssertEqual(
            viewController.preferredContentSize,
            .init(width: 42, height: 42)
        )
    }
}

private var contentScreenSizingOptions: SwiftUIScreenSizingOptions = []

private struct ContentScreen: SwiftUIScreen {
    static func makeView(model: ObservableValue<ContentScreen>) -> some View {
        Color.clear
            .frame(width: 42, height: 42)
    }

    static var sizingOptions: SwiftUIScreenSizingOptions { contentScreenSizingOptions }
}

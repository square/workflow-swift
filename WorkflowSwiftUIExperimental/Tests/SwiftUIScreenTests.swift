import SwiftUI
import UIKit
import WorkflowSwiftUIExperimental
import XCTest

final class SwiftUIScreenTests: XCTestCase {
    func test_noSizingOptions() {
        let viewController = ContentScreen(sizingOptions: [])
            .buildViewController(in: .empty)

        viewController.view.layoutIfNeeded()

        XCTAssertEqual(viewController.preferredContentSize, .zero)
    }

    func test_preferredContentSize() {
        let viewController = ContentScreen(sizingOptions: .preferredContentSize)
            .buildViewController(in: .empty)

        viewController.view.layoutIfNeeded()

        XCTAssertEqual(
            viewController.preferredContentSize,
            .init(width: 42, height: 42)
        )
    }

    func test_preferredContentSize_sizingOptionsChanges() {
        let viewController = ContentScreen(sizingOptions: [])
            .buildViewController(in: .empty)

        viewController.view.layoutIfNeeded()

        XCTAssertEqual(viewController.preferredContentSize, .zero)

        ContentScreen(sizingOptions: .preferredContentSize)
            .viewControllerDescription(environment: .empty)
            .update(viewController: viewController)

        viewController.view.layoutIfNeeded()

        XCTAssertEqual(
            viewController.preferredContentSize,
            .init(width: 42, height: 42)
        )

        ContentScreen(sizingOptions: [])
            .viewControllerDescription(environment: .empty)
            .update(viewController: viewController)

        viewController.view.layoutIfNeeded()

        XCTAssertEqual(viewController.preferredContentSize, .zero)
    }
}

private struct ContentScreen: SwiftUIScreen {
    let sizingOptions: SwiftUIScreenSizingOptions

    static func makeView(model: ObservableValue<ContentScreen>) -> some View {
        Color.clear
            .frame(width: 42, height: 42)
    }
}

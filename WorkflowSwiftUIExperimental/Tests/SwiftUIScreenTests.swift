#if canImport(UIKit)

import SwiftUI
import UIKit
import ViewEnvironment
@_spi(ViewEnvironmentWiring) import ViewEnvironmentUI
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

    func test_viewEnvironmentObservation() {
        // Ensure that environment customizations made on the view controller
        // are propagated to the SwiftUI view environment.

        var emittedValue: Int?

        let viewController = TestKeyEmittingScreen(onTestKeyEmission: { value in
            emittedValue = value
        })
        .buildViewController(in: .empty)

        let lifetime = viewController.addEnvironmentCustomization { environment in
            environment[TestKey.self] = 1
        }

        viewController.view.layoutIfNeeded()

        XCTAssertEqual(emittedValue, 1)

        withExtendedLifetime(lifetime) {}
    }
}

private struct TestKey: ViewEnvironmentKey {
    static var defaultValue: Int = 0
}

extension ViewEnvironment {
    fileprivate var testKey: Int {
        get { self[TestKey.self] }
        set { self[TestKey.self] = newValue }
    }
}

private struct ContentScreen: SwiftUIScreen {
    let sizingOptions: SwiftUIScreenSizingOptions

    static func makeView(model: ObservableValue<ContentScreen>) -> some View {
        Color.clear
            .frame(width: 42, height: 42)
    }
}

private struct TestKeyEmittingScreen: SwiftUIScreen {
    var onTestKeyEmission: (TestKey.Value) -> Void

    let sizingOptions: SwiftUIScreenSizingOptions = [.preferredContentSize]

    static func makeView(model: ObservableValue<Self>) -> some View {
        ContentView(onTestKeyEmission: model.onTestKeyEmission)
    }

    struct ContentView: View {
        @Environment(\.viewEnvironment.testKey)
        var testValue: Int

        var onTestKeyEmission: (TestKey.Value) -> Void

        var body: some View {
            let _ = onTestKeyEmission(testValue)

            Color.clear
                .frame(width: 1, height: 1)
        }
    }
}

#endif

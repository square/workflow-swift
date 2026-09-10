#if canImport(UIKit)

import SwiftUI
import Workflow
import WorkflowSwiftUI
import XCTest

final class PreferredContentSizeTests: XCTestCase {
    func test_preferredContentSize() throws {
        let maxWidth: CGFloat = 50
        let maxHeight: CGFloat = 50

        func assertPreferredContentSize(in axes: Axis.Set, decorated: Bool) {
            let screen = TestScreen(model: .constant(state: State(axes: axes)))
            let viewController = screen.buildViewController(in: .empty)
            if decorated {
                XCTAssertEqual(viewController.decorateObservableScreenContent(with: EmptyModifier()), .installed)
            }

            func assertContentSize(
                _ contentSize: CGSize,
                expected: CGSize? = nil,
                file: StaticString = #filePath,
                line: UInt = #line
            ) {
                let state = State(width: contentSize.width, height: contentSize.height, axes: axes)
                let screen = TestScreen(model: .constant(state: state))
                screen.update(viewController: viewController, with: .empty)

                viewController.view.layoutIfNeeded()
                let pcs = viewController.preferredContentSize

                XCTAssertEqual(
                    pcs,
                    expected ?? contentSize,
                    "Axes: \(axes.testDescription), decorated: \(decorated)",
                    file: file,
                    line: line
                )
            }

            show(viewController: viewController) { _ in
                // Keep the test frame inside the window's safe area on both iPad and iPhone.
                // A fixed 50-point offset still overlaps the sensor housing on some phones.
                let insets = viewController.view.window?.safeAreaInsets ?? .zero
                viewController.view.frame = CGRect(
                    origin: CGPoint(x: insets.left + 50, y: insets.top + 50),
                    size: CGSize(width: maxWidth, height: maxHeight)
                )
                viewController.view.layoutIfNeeded()

                assertContentSize(CGSize(width: 20, height: 20))
                assertContentSize(CGSize(width: 40, height: 20))
                assertContentSize(CGSize(width: 20, height: 40))
                assertContentSize(
                    CGSize(width: 100, height: 100),
                    expected: CGSize(
                        width: axes.contains(.horizontal) ? maxWidth : 100,
                        height: axes.contains(.vertical) ? maxHeight : 100
                    )
                )
            }
        }

        for decorated in [false, true] {
            assertPreferredContentSize(in: [], decorated: decorated)
            assertPreferredContentSize(in: .horizontal, decorated: decorated)
            assertPreferredContentSize(in: .vertical, decorated: decorated)
            assertPreferredContentSize(in: [.horizontal, .vertical], decorated: decorated)
        }
    }
}

extension Axis.Set {
    var testDescription: String {
        switch self {
        case .horizontal: "[horizontal]"
        case .vertical: "[vertical]"
        case [.horizontal, .vertical]: "[horizontal, vertical]"
        default: "[]"
        }
    }
}

@ObservableState
private struct State {
    var width: CGFloat = 0
    var height: CGFloat = 0
    var axes: Axis.Set = []
}

private struct TestWorkflow: Workflow {
    typealias Rendering = StateAccessor<State>

    func makeInitialState() -> State {
        State()
    }

    func render(state: State, context: RenderContext<TestWorkflow>) -> Rendering {
        context.makeStateAccessor(state: state)
    }
}

private struct TestScreen: ObservableScreen {
    typealias Model = StateAccessor<State>

    var model: Model

    var sizingOptions: SwiftUIScreenSizingOptions = .preferredContentSize

    @ViewBuilder
    static func makeView(store: Store<Model>) -> some View {
        TestView(store: store)
    }
}

private struct TestView: View {
    var store: Store<StateAccessor<State>>

    var body: some View {
        WithPerceptionTracking {
            if store.axes.isEmpty {
                box
            } else {
                ScrollView(store.axes) {
                    box
                }
            }
        }
        .ignoresSafeArea()
    }

    var box: some View {
        Color.red.frame(width: store.width, height: store.height)
            .ignoresSafeArea()
    }
}

#endif

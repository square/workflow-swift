#if canImport(UIKit)
import UIKit
import XCTest

import Workflow
import WorkflowUI

final class ScreenContainingTests: XCTestCase {
    func test_findInnermostPrimaryScreen_depth1() {
        let parent = ContainerScreen(child: LeafScreen(identifier: "1"))

        let innermost = parent.findInnermostPrimaryScreen() as? LeafScreen
        XCTAssertEqual(innermost?.identifier, "1")
    }

    func test_findInnermostPrimaryScreen_depth3() {
        let child = LeafScreen(identifier: "3")
        let parent = ContainerScreen(child: child)
        let grandParent = ContainerScreen(child: parent)
        let greatGrandParent = ContainerScreen(child: grandParent).asAnyScreen()

        let innermost = greatGrandParent.findInnermostPrimaryScreen() as? LeafScreen
        XCTAssertEqual(innermost?.identifier, "3")
    }

    func test_findInnermostPrimaryScreen_screenViewController() {
        let viewController: UIViewController = ScreenViewController(screen: LeafScreen(identifier: "leaf").asAnyScreen(), environment: .empty)

        let innermost = (viewController as? SingleScreenContaining)?
            .findInnermostPrimaryScreen() as? LeafScreen

        XCTAssertEqual(innermost?.identifier, "leaf")
    }

    func test_findInnermostPrimaryScreen_workflowHostingController() {
        struct TestWorkflow: Workflow {
            typealias State = Void
            typealias Rendering = LeafScreen
            typealias Output = Never

            func render(state: Void, context: RenderContext<TestWorkflow>) -> LeafScreen {
                LeafScreen(identifier: "hosting-controller-screen")
            }
        }

        let hostingController = WorkflowHostingController(
            workflow: TestWorkflow().mapRendering { $0.asAnyScreen() }
        )

        let innermost = hostingController.findInnermostPrimaryScreen() as? LeafScreen

        XCTAssertEqual(innermost?.identifier, "hosting-controller-screen")
    }
}

private struct ContainerScreen: NoopScreen {
    var child: Screen
}

extension ContainerScreen: SingleScreenContaining {
    var primaryScreen: Screen { child }
}

private struct LeafScreen: NoopScreen {
    var identifier: String
}

private protocol NoopScreen: Screen {}
extension NoopScreen {
    func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
        .init(environment: .empty, build: UIViewController.init, update: { _ in })
    }
}
#endif

import XCTest

import WorkflowUI

final class ScreenContainingTests: XCTestCase {
    func test_findInnermostScreen_depth1() {
        let parent = ContainerScreen(child: LeafScreen(identifier: "1"))

        let innermost = parent.findInnermostScreen() as? LeafScreen
        XCTAssertEqual(innermost?.identifier, "1")
    }

    func test_findInnermostScreen_depth3() {
        let child = LeafScreen(identifier: "3")
        let parent = ContainerScreen(child: child)
        let grandParent = ContainerScreen(child: parent)
        let greatGrandParent = ContainerScreen(child: grandParent)

        let innermost = greatGrandParent.findInnermostScreen() as? LeafScreen
        XCTAssertEqual(innermost?.identifier, "3")
    }
}

private struct ContainerScreen: NoopScreen {
    var child: Screen
}

extension ContainerScreen: ScreenContaining {
    var containedScreen: Screen { child }
}

private struct LeafScreen: NoopScreen {
    var identifier: String
}

private protocol NoopScreen: Screen {}
extension NoopScreen {
    func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
        fatalError()
    }
}

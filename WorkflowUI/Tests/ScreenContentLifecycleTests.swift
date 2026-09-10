#if canImport(UIKit)

import Testing
import UIKit
@testable import WorkflowUI

@MainActor
struct ScreenContentLifecycleTests {
    @Test
    func `Replacement retires all old content before preparing unloaded new content`() {
        let first = UIViewController()
        let second = UIViewController()
        let lifecycle = ScreenContentLifecycle(viewController: first)
        var events: [String] = []
        let observations = (1 ... 2).map { index in
            lifecycle.observe { controller in
                #expect(!controller.isViewLoaded)
                let name = controller === first ? "first" : "second"
                events.append("prepare \(name) \(index)")
                return { events.append("retire \(name) \(index)") }
            }
        }
        lifecycle.replace(with: first)
        #expect(events == ["prepare first 1", "prepare first 2"])
        lifecycle.replace(with: second)
        #expect(events == [
            "prepare first 1", "prepare first 2", "retire first 1", "retire first 2",
            "prepare second 1", "prepare second 2",
        ])
        #expect(lifecycle.viewController === second)
        #expect(!first.isViewLoaded && !second.isViewLoaded)
        observations.forEach { $0.remove() }
        observations.forEach { $0.remove() }
        #expect(events.suffix(2) == ["retire second 1", "retire second 2"])
        lifecycle.replace(with: UIViewController())
        #expect(events.count == 8)
    }

    @Test
    func `Releasing an observation retires once and stops replacement callbacks`() {
        let lifecycle = ScreenContentLifecycle(viewController: UIViewController())
        var preparations = 0
        var retirements = 0
        var observation: ScreenContentLifecycle.Observation? = lifecycle.observe { _ in
            preparations += 1
            return { retirements += 1 }
        }
        #expect(observation != nil)
        observation = nil
        lifecycle.replace(with: UIViewController())
        #expect(preparations == 1)
        #expect(retirements == 1)
    }

    @Test
    func `Ending a lifecycle retires an externally retained observation`() {
        var lifecycle: ScreenContentLifecycle? = .init(viewController: UIViewController())
        var retirements = 0
        let observation = lifecycle?.observe { _ in { retirements += 1 } }
        lifecycle = nil
        #expect(retirements == 1)
        observation?.remove()
        #expect(retirements == 1)
    }
}

#endif

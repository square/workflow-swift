/*
 * Copyright 2020 Square Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#if canImport(UIKit)

import XCTest

import ReactiveSwift
import Workflow
@_spi(DynamicControllerTypes) @testable import WorkflowUI

fileprivate class BlankViewController: UIViewController {}
fileprivate class BlankViewControllerSubclass: BlankViewController {}
fileprivate class SecondBlankViewController: UIViewController {}

@objc fileprivate protocol MyProtocol {
    func update()
}

class ViewControllerDescriptionTests: XCTestCase {
    func test_build() {
        let description = ViewControllerDescription(
            environment: .empty,
            build: { BlankViewController() },
            update: { _ in }
        )

        // Check built view controller
        let viewController = description.buildViewController()
        XCTAssertTrue(type(of: viewController) == BlankViewController.self)

        // Check another built view controller isn’t somehow the same instance
        let viewControllerAgain = description.buildViewController()
        XCTAssertFalse(viewController === viewControllerAgain)
    }

    func test_canUpdate() {
        let description = ViewControllerDescription(
            environment: .empty,
            build: { BlankViewController() },
            update: { _ in }
        )

        let viewController = description.buildViewController()
        XCTAssertTrue(description.canUpdate(viewController: viewController))

        let otherViewController = UIViewController()
        XCTAssertFalse(description.canUpdate(viewController: otherViewController))

        final class SubclassViewController: BlankViewController {}

        // We can update subclasses too, as long as they pass an "is/as?" check.
        let subclassViewController = SubclassViewController()
        XCTAssertTrue(description.canUpdate(viewController: subclassViewController))
    }

    func test_canUpdate_abstractViewController() {
        func makeAbstractViewController() -> UIViewController & MyProtocol {
            class ConcreteViewController: UIViewController, MyProtocol {
                func update() {}
            }
            return ConcreteViewController()
        }

        let viewController = makeAbstractViewController()

        let description = ViewControllerDescription(
            environment: .empty,
            build: { viewController },
            update: { $0.update() }
        )

        XCTAssertTrue(description.canUpdate(viewController: viewController))
        XCTAssertFalse(description.canUpdate(viewController: UIViewController()))
    }

    func test_performInitialUpdate() {
        var updateCount = 0
        let description = ViewControllerDescription(
            performInitialUpdate: false,
            environment: .empty,
            build: { BlankViewController() },
            update: { _ in updateCount += 1 }
        )

        XCTAssertEqual(updateCount, 0)

        // Build should not cause an initial update when
        let viewController = description.buildViewController()
        XCTAssertEqual(updateCount, 0)

        description.update(viewController: viewController)
        XCTAssertEqual(updateCount, 1)
    }

    func test_update() {
        var updateCount = 0
        let description = ViewControllerDescription(
            environment: .empty,
            build: { BlankViewController() },
            update: { viewController in
                XCTAssertTrue(type(of: viewController) == BlankViewController.self)
                updateCount += 1
            }
        )

        XCTAssertEqual(updateCount, 0)

        // Build causes an initial update
        let viewController = description.buildViewController()
        XCTAssertEqual(updateCount, 1)

        description.update(viewController: viewController)
        XCTAssertEqual(updateCount, 2)

        description.update(viewController: viewController)
        XCTAssertEqual(updateCount, 3)
    }

    func test_environment_propagation() throws {
        final class EnvironmentObservingViewController: UIViewController, ViewEnvironmentObserving {
            let onEnvironmentDidChange: (ViewEnvironment) -> Void
            init(onEnvironmentDidChange: @escaping (ViewEnvironment) -> Void) {
                self.onEnvironmentDidChange = onEnvironmentDidChange
                super.init(nibName: nil, bundle: nil)
            }

            @available(*, unavailable)
            required init?(coder: NSCoder) { fatalError() }
            func environmentDidChange() { onEnvironmentDidChange(environment) }
        }

        struct TestKey: ViewEnvironmentKey {
            static var defaultValue: Int = 0
        }

        var changedEnvironments: [ViewEnvironment] = []

        func makeViewController() -> EnvironmentObservingViewController {
            EnvironmentObservingViewController { changedEnvironments.append($0) }
        }

        func makeDescription(testValue: Int) -> ViewControllerDescription {
            ViewControllerDescription(
                environment: .empty.setting(key: TestKey.self, to: testValue),
                build: makeViewController,
                update: { _ in }
            )
        }

        XCTAssertEqual(changedEnvironments.count, 0)

        let viewController = makeDescription(testValue: 1)
            .buildViewController()

        XCTAssertEqual(changedEnvironments.count, 1)
        do {
            let environment = try XCTUnwrap(changedEnvironments.last)
            XCTAssertEqual(environment[TestKey.self], 1)
        }

        makeDescription(testValue: 2)
            .update(viewController: viewController)

        XCTAssertEqual(changedEnvironments.count, 2)
        do {
            let environment = try XCTUnwrap(changedEnvironments.last)
            XCTAssertEqual(environment[TestKey.self], 2)
        }
    }

    func test_screenViewController() {
        // Make sure ScreenViewController<T>.description(for:) generates a correct view controller
        // description

        struct MyScreen: Screen {
            func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
                MyScreenViewController.description(for: self, environment: environment)
            }
        }

        final class MyScreenViewController: ScreenViewController<MyScreen> {}

        let screen = MyScreen()
        let description = screen.viewControllerDescription(environment: .empty)

        let viewController = description.buildViewController()
        XCTAssertTrue(type(of: viewController) == MyScreenViewController.self)

        XCTAssertTrue(description.canUpdate(viewController: viewController))

        let viewControllerAgain = description.buildViewController()
        XCTAssertFalse(viewController === viewControllerAgain)
    }

    func test_viewControllerTypes() {
        func polymorphicController() -> UIViewController { BlankViewController() }
        let controller = polymorphicController()

        // Case 1: Dynamic type inspection.
        // kind.viewControllerType == BlankViewController.self.
        let descriptionWithDynamicType = ViewControllerDescription(
            dynamicType: type(of: controller),
            environment: .empty,
            build: { controller },
            update: { _ in }
        )
        // canUpdate(viewController:) will evaluate to true for matching UIViewController types or subclasses.
        XCTAssertTrue(descriptionWithDynamicType.canUpdate(viewController: polymorphicController()))
        XCTAssertTrue(descriptionWithDynamicType.canUpdate(viewController: BlankViewController()))
        XCTAssertFalse(descriptionWithDynamicType.canUpdate(viewController: UIViewController()))
        XCTAssertFalse(descriptionWithDynamicType.canUpdate(viewController: SecondBlankViewController()))
        XCTAssertTrue(descriptionWithDynamicType.canUpdate(viewController: BlankViewControllerSubclass()))

        // Case 2: Example of static types losing granularity when supplying a superclass type.
        // kind.viewControllerType == UIViewController.self.
        let descriptionWithStaticSupertype = ViewControllerDescription(
            type: type(of: controller),
            environment: .empty,
            build: { controller },
            update: { _ in }
        )
        // canUpdate(viewController:) evaluates to true for any UIViewController type.
        XCTAssertTrue(descriptionWithStaticSupertype.canUpdate(viewController: polymorphicController()))
        XCTAssertTrue(descriptionWithStaticSupertype.canUpdate(viewController: BlankViewController()))
        XCTAssertTrue(descriptionWithStaticSupertype.canUpdate(viewController: UIViewController()))
        XCTAssertTrue(descriptionWithStaticSupertype.canUpdate(viewController: SecondBlankViewController()))
        XCTAssertTrue(descriptionWithStaticSupertype.canUpdate(viewController: BlankViewControllerSubclass()))

        // Case 3: Common/standard Workflow use case with static types.
        // kind.viewControllerType == BlankViewController.self.
        let descriptionWithStaticSubtype = ViewControllerDescription(
            type: BlankViewController.self,
            environment: .empty,
            build: { BlankViewController() },
            update: { _ in }
        )
        // canUpdate(viewController:) will evaluate to true for matching UIViewController types or subclasses.
        XCTAssertTrue(descriptionWithStaticSubtype.canUpdate(viewController: polymorphicController()))
        XCTAssertTrue(descriptionWithStaticSubtype.canUpdate(viewController: BlankViewController()))
        XCTAssertFalse(descriptionWithStaticSubtype.canUpdate(viewController: UIViewController()))
        XCTAssertFalse(descriptionWithStaticSubtype.canUpdate(viewController: SecondBlankViewController()))
        XCTAssertTrue(descriptionWithStaticSubtype.canUpdate(viewController: BlankViewControllerSubclass()))
    }
}

class ViewControllerDescription_KindIdentifierTests: XCTestCase {
    private final class VC1: UIViewController {}
    private final class VC2: UIViewController {}

    func test_kind() {
        let kind1 = ViewControllerDescription.KindIdentifier(VC1.self)
        let kind2 = ViewControllerDescription.KindIdentifier(VC2.self)

        XCTAssertEqual(kind1, kind1)
        XCTAssertNotEqual(kind1, kind2)

        let vc1 = VC1()
        let vc2 = VC2()

        XCTAssertTrue(kind1.canUpdate(viewController: vc1))
        XCTAssertFalse(kind1.canUpdate(viewController: vc2))
    }
}

#endif

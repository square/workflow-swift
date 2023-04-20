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

import UIKit

public final class DescribedViewController: UIViewController {
    public typealias CustomizeEnvironment = (inout ViewEnvironment) -> Void

    public var customizeEnvironment: CustomizeEnvironment {
        didSet { setNeedsEnvironmentUpdate() }
    }

    var screen: AnyScreen
    var currentViewController: UIViewController

    public init<S: Screen>(
        screen: S,
        customizeEnvironment: @escaping (inout ViewEnvironment) -> Void = { _ in }
    ) {
        self.screen = screen.asAnyScreen()
        self.customizeEnvironment = customizeEnvironment

        var environment: ViewEnvironment = .empty
        customizeEnvironment(&environment)

        self.currentViewController = screen
            .viewControllerDescription(environment: environment)
            .buildViewController()

        super.init(nibName: nil, bundle: nil)

        addChild(currentViewController)
        currentViewController.didMove(toParent: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    public func update<S: Screen>(screen: S) {
        self.screen = screen.asAnyScreen()

        let description = screen.viewControllerDescription(environment: environment)

        if description.canUpdate(viewController: currentViewController) {
            description.update(viewController: currentViewController)
        } else {
            currentViewController.willMove(toParent: nil)
            currentViewController.viewIfLoaded?.removeFromSuperview()
            currentViewController.removeFromParent()

            currentViewController = description.buildViewController()

            addChild(currentViewController)

            if isViewLoaded {
                currentViewController.view.frame = view.bounds
                view.addSubview(currentViewController.view)
                updatePreferredContentSizeIfNeeded()
            }

            currentViewController.didMove(toParent: self)

            updatePreferredContentSizeIfNeeded()
        }
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        currentViewController.view.frame = view.bounds
        view.addSubview(currentViewController.view)

        updatePreferredContentSizeIfNeeded()
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        currentViewController.view.frame = view.bounds
    }

    override public var childForStatusBarStyle: UIViewController? {
        return currentViewController
    }

    override public var childForStatusBarHidden: UIViewController? {
        return currentViewController
    }

    override public var childForHomeIndicatorAutoHidden: UIViewController? {
        return currentViewController
    }

    override public var childForScreenEdgesDeferringSystemGestures: UIViewController? {
        return currentViewController
    }

    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return currentViewController.supportedInterfaceOrientations
    }

    override public var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return currentViewController.preferredStatusBarUpdateAnimation
    }

    override public var childViewControllerForPointerLock: UIViewController? {
        return currentViewController
    }

    override public func preferredContentSizeDidChange(
        forChildContentContainer container: UIContentContainer
    ) {
        super.preferredContentSizeDidChange(forChildContentContainer: container)

        guard container === currentViewController else { return }

        updatePreferredContentSizeIfNeeded()
    }

    private func updatePreferredContentSizeIfNeeded() {
        let newPreferredContentSize = currentViewController.preferredContentSize

        guard newPreferredContentSize != preferredContentSize else { return }

        preferredContentSize = newPreferredContentSize
    }
}

extension DescribedViewController: ViewEnvironmentObserving {
    public func customize(environment: inout ViewEnvironment) {
        customizeEnvironment(&environment)
    }

    public func environmentDidChange() {
        update(screen: screen)
    }
}

#endif

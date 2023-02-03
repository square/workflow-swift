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
    var currentViewController: UIViewController

    public init(description: ViewControllerDescription) {
        self.currentViewController = description.buildViewController()
        super.init(nibName: nil, bundle: nil)

        addChild(currentViewController)
        currentViewController.didMove(toParent: self)
    }

    public convenience init<S: Screen>(screen: S, environment: ViewEnvironment) {
        self.init(description: screen.viewControllerDescription(environment: environment))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    public func update(description: ViewControllerDescription) {
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

    public func update<S: Screen>(screen: S, environment: ViewEnvironment) {
        update(description: screen.viewControllerDescription(environment: environment))
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
#endif

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

    /// Displays the backing `ViewControllerDescription` for a given `Screen`.
    public final class DescribedViewController: UIViewController {
        var content: UIViewController

        /// Creates a new view controller with the given description.
        public init(description: ViewControllerDescription) {
            self.content = description.buildViewController()
            super.init(nibName: nil, bundle: nil)

            addChild(content)
            content.didMove(toParent: self)
        }

        /// Creates a new view controller with the screen and environment.
        public convenience init<S: Screen>(screen: S, environment: ViewEnvironment) {
            self.init(description: screen.viewControllerDescription(environment: environment))
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) is unavailable")
        }

        /// Updates the content of the view controller with the given description.
        /// If the view controller can't be updated (because it's type is not the same), the old
        /// content will be transitioned out, and the new one will be transitioned in
        /// with the new description's `ViewTransition`.
        public func update(description: ViewControllerDescription, animated: Bool = true) {
            if description.canUpdate(viewController: content) {
                description.update(viewController: content)
            } else {
                let old = content
                let new = description.buildViewController()

                content = new

                if isViewLoaded {
                    let animated = animated && view.window != nil

                    addChild(new)
                    old.willMove(toParent: nil)

                    description.transition.transition(
                        from: old.view,
                        to: new.view,
                        in: view,
                        animated: animated,
                        setup: {
                            new.view.frame = self.view.bounds
                            self.view.addSubview(new.view)
                        },
                        completion: {
                            new.didMove(toParent: self)

                            old.view.removeFromSuperview()
                            old.removeFromParent()

                            self.currentViewControllerChanged()
                            self.updatePreferredContentSizeIfNeeded()
                        }
                    )
                } else {
                    addChild(new)
                    new.didMove(toParent: self)

                    old.willMove(toParent: nil)
                    old.removeFromParent()

                    updatePreferredContentSizeIfNeeded()
                }
            }
        }

        public func update<S: Screen>(screen: S, environment: ViewEnvironment, animated: Bool = true) {
            update(description: screen.viewControllerDescription(environment: environment), animated: animated)
        }

        override public func viewDidLoad() {
            super.viewDidLoad()

            content.view.frame = view.bounds
            view.addSubview(content.view)

            updatePreferredContentSizeIfNeeded()
        }

        override public func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            content.view.frame = view.bounds
        }

        override public var childForStatusBarStyle: UIViewController? {
            return content
        }

        override public var childForStatusBarHidden: UIViewController? {
            return content
        }

        override public var childForHomeIndicatorAutoHidden: UIViewController? {
            return content
        }

        override public var childForScreenEdgesDeferringSystemGestures: UIViewController? {
            return content
        }

        override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
            return content.supportedInterfaceOrientations
        }

        override public var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
            return content.preferredStatusBarUpdateAnimation
        }

        @available(iOS 14.0, *)
        override public var childViewControllerForPointerLock: UIViewController? {
            return content
        }

        override public func preferredContentSizeDidChange(
            forChildContentContainer container: UIContentContainer
        ) {
            super.preferredContentSizeDidChange(forChildContentContainer: container)

            guard container === content else { return }

            updatePreferredContentSizeIfNeeded()
        }

        private func updatePreferredContentSizeIfNeeded() {
            let newPreferredContentSize = content.preferredContentSize

            guard newPreferredContentSize != preferredContentSize else { return }

            preferredContentSize = newPreferredContentSize
        }

        private func currentViewControllerChanged() {
            setNeedsFocusUpdate()
            setNeedsUpdateOfHomeIndicatorAutoHidden()

            if #available(iOS 14.0, *) {
                self.setNeedsUpdateOfPrefersPointerLocked()
            }

            setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
            setNeedsStatusBarAppearanceUpdate()

            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
    }
#endif

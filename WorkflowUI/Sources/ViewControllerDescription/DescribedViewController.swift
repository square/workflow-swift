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
        private(set) var content: UIViewController

        // MARK: Initialization

        public init(with description: ViewControllerDescription) {
            self.content = description.buildViewController()
            super.init(nibName: nil, bundle: nil)

            addChild(content)
            content.didMove(toParent: self)
        }

        public convenience init<S: Screen>(with screen: S, environment: ViewEnvironment) {
            self.init(with: screen.viewControllerDescription(environment: environment))
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) is unavailable")
        }

        // MARK: Updating Content

        public func update(with description: ViewControllerDescription, animated: Bool = false) {
            if description.canUpdate(viewController: content) {
                description.update(viewController: content)
            } else {
                let old = content
                let new = description.buildViewController()

                content = new

                if isViewLoaded {
                    addChild(new)
                    old.willMove(toParent: nil)

                    description.transition.transition(
                        from: old.view,
                        to: new.view,
                        in: view,
                        animated: animated,
                        setup: {
                            self.view.addSubview(new.view)
                            self.preferredContentSize = new.preferredContentSize

                            self.currentViewControllerChanged()
                        },
                        completion: {
                            new.didMove(toParent: self)

                            old.view.removeFromSuperview()
                            old.removeFromParent()
                        }
                    )

                } else {
                    addChild(new)
                    new.didMove(toParent: self)

                    old.willMove(toParent: nil)
                    old.removeFromParent()
                }
            }
        }

        public func update<S: Screen>(
            screen: S,
            environment: ViewEnvironment,
            animated: Bool = false
        ) {
            update(
                with: screen.viewControllerDescription(environment: environment),
                animated: animated
            )
        }

        // MARK: UIViewController

        override public func loadView() {
            super.loadView()

            content.view.frame = view.bounds
            view.addSubview(content.view)

            preferredContentSize = content.preferredContentSize
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

        override public func preferredContentSizeDidChange(forChildContentContainer container: UIContentContainer) {
            super.preferredContentSizeDidChange(forChildContentContainer: container)

            guard
                (container as? UIViewController) == content,
                container.preferredContentSize != preferredContentSize
            else { return }

            preferredContentSize = container.preferredContentSize
        }

        // MARK: Private

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

    // MARK: Deprecations

    public extension DescribedViewController {
        @available(*, deprecated, renamed: "init(with:)")
        convenience init(description: ViewControllerDescription) {
            self.init(with: description)
        }

        @available(*, deprecated, renamed: "init(with:environment:)")
        convenience init<S: Screen>(screen: S, environment: ViewEnvironment) {
            self.init(with: screen.viewControllerDescription(environment: environment))
        }

        @available(*, deprecated, renamed: "update(with:)")
        func update(description: ViewControllerDescription) {
            update(with: description, animated: false)
        }
    }

#endif

/*
 * Copyright 2021 Square Inc.
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

    /// When the `UIViewController` backing a `DescribedViewController` changes,
    /// the `ViewTransition` provided from the `ViewControllerDescription`
    /// will be used to animate in the new view controller and animate out the old view controller.
    ///
    /// There are default transition types provided, for example `.fade` and `.scale`. If you would like
    /// to create your own transition, create an instance of this type and provide the appropriate `setup` and `animate` actions.
    public struct ViewTransition {
        /// Creates a new transition with the provided setup and animation actions
        ///
        /// The `setup` action will be performed without animation – use it to set
        /// up any initial view frames, opacities, etc.
        ///
        /// In the `animate` action, perform your animation with your desired animation APIs
        /// such as `UIView.animate(withDuration: ...)`, etc. Once the animation
        /// is complete, call `context.setComplete()` to mark your animation as fully complete.
        public init(
            setup: @escaping (Context) -> Void,
            animate: @escaping (Context) -> Void
        ) {
            self.setup = setup
            self.animate = animate
        }

        func transition(
            from: UIView,
            to: UIView,
            in container: UIView,
            animated: Bool,
            setup: @escaping () -> Void,
            completion: @escaping () -> Void
        ) {
            if animated {
                let context = Context(from: from, to: to, in: container, completion: completion)

                UIView.performWithoutAnimation {
                    self.setup(context)
                    setup()
                }

                animate(context)
            } else {
                to.frame = container.bounds

                setup()
                completion()
            }
        }

        private let setup: (Context) -> Void
        private let animate: (Context) -> Void
    }

    public extension ViewTransition {
        /// An instant transition from the old view controller to the new view controller with no animation.
        static var none: Self {
            .init(
                setup: { context in
                    context.to.frame = context.container.bounds
                },
                animate: { context in
                    context.setCompleted()
                }
            )
        }

        /// Fades in the new view controller over the old view controller with the provided duration.
        static func fade(with duration: TimeInterval = 0.15) -> Self {
            .init(
                setup: { context in
                    context.to.frame = context.container.bounds
                    context.to.alpha = 0.0
                },
                animate: { context in
                    UIView.animate(withDuration: duration) {
                        context.to.alpha = 1.0
                    } completion: { _ in
                        context.setCompleted()
                    }
                }
            )
        }

        /// Fades and scales in the new view controller over the old view controller with the provided duration.
        static func scale(with duration: TimeInterval = 0.15) -> Self {
            .init(
                setup: { context in
                    context.to.frame = context.container.bounds
                    context.to.alpha = 0.0
                    context.to.transform = .init(scaleX: 1.25, y: 1.25)
                },
                animate: { context in
                    UIView.animate(withDuration: duration) {
                        context.to.alpha = 1.0
                        context.to.transform = .identity
                    } completion: { _ in
                        context.setCompleted()
                    }
                }
            )
        }
    }

    public extension ViewTransition {
        /// Passed to a `ViewTransition`'s `setup` and `animate`
        /// actions to provide access to the `from`, `to` views, as well as allows
        /// notifying the the transition that any required animations have been completed.
        final class Context {
            /// The view that is being transitioned away from.
            /// It is at the bottom of the view hierarchy, below the `to` view.
            public let from: UIView

            /// The view that is being transitioned to.
            /// It is at the top of the view hierarchy, above the `from` view.
            public let to: UIView

            /// The container view that is being used to coordinate the transition.
            public let container: UIView

            /// Marks the transition as completed. Call this method once your
            /// transition animations are completed to signal to the `DescribedViewController`
            /// that it should fully complete the transition.
            ///
            /// You should only call this method once. Calling it multiple times will result in a fatal error.
            public func setCompleted() {
                guard case .running(let running) = state else {
                    fatalError(
                        """
                        WorkflowUI ViewTransition Error: `setCompleted()` was called multiple times to signal \
                        the end of a transition animation. Please only call setCompleted once.
                        """
                    )
                }

                state = .complete

                running.completion()
            }

            init(from: UIView, to: UIView, in container: UIView, completion: @escaping () -> Void) {
                self.from = from
                self.to = to
                self.container = container
                self.state = .running(.init(completion: completion))
            }

            private var state: State
        }
    }

    extension ViewTransition.Context {
        private enum State {
            case running(Running)
            case complete

            struct Running {
                var completion: () -> Void
            }
        }
    }

#endif

import UIKit

#if canImport(UIKit)

    /**
     Embeds a wrapped `Screen`'s backing view controller as a child view controller with a matching frame.

     This `Screen` can be useful wen you'd like to add view controller functionality to an existing `Screen` when you
     don't have access to the backing view controller. For example, you might use a `WrapperScreen` to present a share
     sheet over an existing `Screen`.

     `WrapperScreen` is intended for use with a `WrapperScreenViewController` subclass. `WrapperScreenViewController`
     handles embedding the wrapped `Screen`, adding it's backing view controller as a child, and updating its frame to
     match the the backing view, forwards child view controller methods, updates the wrapped screen when appropriate.

     Provide a view controller description of your `WrapperScreenViewController` subclass in your conformance to
     `WrapperScreen`:

     ````
     struct MyWrapper {
         var wrapped: Content
     }

     extension ShareSheetScreen: WrapperScreen, Screen where Content: Screen {
         public func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
             MyWrapperScreenViewController<Content>.description(for: self, environment: environment)
         }
     }
     ````

     See `WrapperScreenViewController` for more information on how write your view controller subclass.
     */
    public protocol WrapperScreen: Screen {
        /// The type of the `Screen` being wrapped.
        associatedtype Wrapped: Screen

        /// The `Screen` being wrapped.
        var wrapped: Wrapped { get }
    }

    /**
     The superclass for the backing view controller of a `WrapperScreen`.
     */
    open class WrapperScreenViewController<ScreenType: WrapperScreen>: ScreenViewController<ScreenType> {
        let wrappedViewController: DescribedViewController

        public required init(screen: ScreenType, environment: ViewEnvironment) {
            self.wrappedViewController = DescribedViewController(screen: screen.wrapped, environment: environment)

            super.init(screen: screen, environment: environment)

            addChild(wrappedViewController)
            wrappedViewController.didMove(toParent: self)
        }

        /// Subclasses should override this method in order to update any relevant UI bits when the screen model
        /// changes.
        ///
        /// You must call `super.screenDidChange(from: previousScreen, previousEnvironment: previousEnvironment)` in
        /// your implementation.
        override open func screenDidChange(from previousScreen: ScreenType, previousEnvironment: ViewEnvironment) {
            super.screenDidChange(from: previousScreen, previousEnvironment: previousEnvironment)

            wrappedViewController.update(screen: screen.wrapped, environment: environment)
        }

        override open func loadView() {
            view = UIView(frame: UIScreen.main.bounds)

            view.addSubview(wrappedViewController.view)

            updatePreferredContentSizeIfNeeded()
        }

        override open func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()

            wrappedViewController.view.frame = view.bounds
        }

        override open var childForStatusBarStyle: UIViewController? {
            return wrappedViewController
        }

        override open var childForStatusBarHidden: UIViewController? {
            return wrappedViewController
        }

        override open var childForHomeIndicatorAutoHidden: UIViewController? {
            return wrappedViewController
        }

        override open var childForScreenEdgesDeferringSystemGestures: UIViewController? {
            return wrappedViewController
        }

        override open var supportedInterfaceOrientations: UIInterfaceOrientationMask {
            return wrappedViewController.supportedInterfaceOrientations
        }

        override open var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
            return wrappedViewController.preferredStatusBarUpdateAnimation
        }

        @available(iOS 14.0, *)
        override open var childViewControllerForPointerLock: UIViewController? {
            return wrappedViewController
        }

        override open func preferredContentSizeDidChange(
            forChildContentContainer container: UIContentContainer
        ) {
            super.preferredContentSizeDidChange(forChildContentContainer: container)

            guard container === wrappedViewController else { return }

            updatePreferredContentSizeIfNeeded()
        }

        open func updatePreferredContentSizeIfNeeded() {
            let newPreferredContentSize = wrappedViewController.preferredContentSize

            guard newPreferredContentSize != preferredContentSize else { return }

            preferredContentSize = newPreferredContentSize
        }

        @available(*, unavailable)
        public required init?(coder: NSCoder) {
            fatalError("init?(coder:) has not been implemented.")
        }
    }

#endif

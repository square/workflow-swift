#if canImport(UIKit)

import SwiftUI
import WorkflowUI

// MARK: - ViewEnvironmentHolder / ViewEnvironmentModifier

final class ViewEnvironmentHolder: ObservableObject {
    @Published var viewEnvironment: ViewEnvironment

    init(viewEnvironment: ViewEnvironment) {
        self.viewEnvironment = viewEnvironment
    }
}

struct ViewEnvironmentModifier: ViewModifier {
    @ObservedObject var holder: ViewEnvironmentHolder

    func body(content: Content) -> some View {
        content
            .environment(\.viewEnvironment, holder.viewEnvironment)
    }
}

// MARK: - _HostingScreenViewController

/// Internal base class for `ObservableScreenViewController` and
/// `SelfContainedScreenViewController`. Contains all shared UIHostingController
/// machinery: environment injection, sizing, and UIViewController preference forwarding.
class _HostingScreenViewController<ScreenType: _HostingScreen, Content: View>:
    UIHostingController<ModifiedContent<Content, ViewEnvironmentModifier>>,
    ViewEnvironmentObserving
{
    var screen: ScreenType
    let viewEnvironmentHolder: ViewEnvironmentHolder

    private var hasLaidOutOnce = false
    private var maxFrameWidth: CGFloat = 0
    private var maxFrameHeight: CGFloat = 0

    private var previousPreferredStatusBarStyle: UIStatusBarStyle?
    private var previousPrefersStatusBarHidden: Bool?
    private var previousSupportedInterfaceOrientations: UIInterfaceOrientationMask?
    private var previousPreferredScreenEdgesDeferringSystemGestures: UIRectEdge?
    private var previousPrefersHomeIndicatorAutoHidden: Bool?

    init(
        viewEnvironment: ViewEnvironment,
        rootView: Content,
        screen: ScreenType
    ) {
        self.viewEnvironmentHolder = ViewEnvironmentHolder(viewEnvironment: viewEnvironment)
        self.screen = screen

        super.init(
            rootView: rootView
                .modifier(ViewEnvironmentModifier(holder: viewEnvironmentHolder))
        )

        updateSizingOptionsIfNeeded()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("not implemented")
    }

    func update(screen: ScreenType) {
        self.screen = screen
        updateViewControllerContainmentForwarding()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // `UIHostingController` provides a system background color by default. We set the
        // background to clear to support contexts where it is composed within another view
        // controller.
        view.backgroundColor = .clear

        setNeedsLayoutBeforeFirstLayoutIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        defer { hasLaidOutOnce = true }

        if screen.sizingOptions.contains(.preferredContentSize) {
            // Use the largest frame ever laid out in as a constraint for preferredContentSize
            // measurements.
            let width = max(view.frame.width, maxFrameWidth)
            let height = max(view.frame.height, maxFrameHeight)

            maxFrameWidth = width
            maxFrameHeight = height

            let fixedSize = CGSize(width: width, height: height)

            // Measure a few different ways to account for ScrollView behavior. ScrollViews will
            // always greedily fill the space available, but will report the natural content size
            // when given an infinite size. By combining the results of these measurements we can
            // deduce the natural size of content that scrolls in either direction, or both, or
            // neither.

            let fixedResult = view.sizeThatFits(fixedSize)
            let unboundedHorizontalResult = view.sizeThatFits(CGSize(width: .infinity, height: fixedSize.height))
            let unboundedVerticalResult = view.sizeThatFits(CGSize(width: fixedSize.width, height: .infinity))

            let size = CGSize(
                width: min(fixedResult.width, unboundedHorizontalResult.width),
                height: min(fixedResult.height, unboundedVerticalResult.height)
            )

            if preferredContentSize != size {
                preferredContentSize = size
            }
        } else if preferredContentSize != .zero {
            preferredContentSize = .zero
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        applyEnvironmentIfNeeded()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        screen.preferredStatusBarStyle(in: makeCurrentContext())
    }

    override var prefersStatusBarHidden: Bool {
        screen.prefersStatusBarHidden(in: makeCurrentContext())
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        screen.preferredStatusBarUpdateAnimation(in: makeCurrentContext())
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        screen.supportedInterfaceOrientations(in: makeCurrentContext())
    }

    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        screen.preferredScreenEdgesDeferringSystemGestures(in: makeCurrentContext())
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        screen.prefersHomeIndicatorAutoHidden(in: makeCurrentContext())
    }

    override func accessibilityPerformEscape() -> Bool {
        screen.accessibilityPerformEscape()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let handled = screen.pressesBegan(presses, with: event)
        if !handled {
            super.pressesBegan(presses, with: event)
        }
    }

    private func makeCurrentContext() -> HostingScreenContext {
        HostingScreenContext(
            environment: environment,
            safeAreaInsets: viewIfLoaded?.safeAreaInsets ?? .zero,
            windowSize: view.window?.bounds.size
        )
    }

    private func updateSizingOptionsIfNeeded() {
        if !screen.sizingOptions.contains(.preferredContentSize), preferredContentSize != .zero {
            preferredContentSize = .zero
        }
    }

    func updateViewControllerContainmentForwarding() {
        // Update status bar.
        let preferredStatusBarStyle = preferredStatusBarStyle
        let prefersStatusBarHidden = prefersStatusBarHidden
        if (previousPreferredStatusBarStyle != nil && previousPreferredStatusBarStyle != preferredStatusBarStyle) ||
            (previousPrefersStatusBarHidden != nil && previousPrefersStatusBarHidden != prefersStatusBarHidden)
        {
            setNeedsStatusBarAppearanceUpdate()
        }
        previousPreferredStatusBarStyle = preferredStatusBarStyle
        previousPrefersStatusBarHidden = prefersStatusBarHidden

        // Update interface orientation.
        let supportedInterfaceOrientations = supportedInterfaceOrientations
        if previousSupportedInterfaceOrientations != nil,
           previousSupportedInterfaceOrientations != supportedInterfaceOrientations
        {
            setNeedsUpdateOfSupportedInterfaceOrientationsAndRotateIfNeeded()
        }
        previousSupportedInterfaceOrientations = supportedInterfaceOrientations

        // Update screen edges deferring system gestures.
        let preferredScreenEdgesDeferringSystemGestures = preferredScreenEdgesDeferringSystemGestures
        if previousPreferredScreenEdgesDeferringSystemGestures != nil,
           previousPreferredScreenEdgesDeferringSystemGestures != preferredScreenEdgesDeferringSystemGestures
        {
            setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        }
        previousPreferredScreenEdgesDeferringSystemGestures = preferredScreenEdgesDeferringSystemGestures

        // Update home indicator visibility.
        let prefersHomeIndicatorAutoHidden = prefersHomeIndicatorAutoHidden
        if previousPrefersHomeIndicatorAutoHidden != nil,
           previousPrefersHomeIndicatorAutoHidden != prefersHomeIndicatorAutoHidden
        {
            setNeedsUpdateOfHomeIndicatorAutoHidden()
        }
        previousPrefersHomeIndicatorAutoHidden = prefersHomeIndicatorAutoHidden
    }

    private func setNeedsLayoutBeforeFirstLayoutIfNeeded() {
        if screen.sizingOptions.contains(.preferredContentSize), !hasLaidOutOnce {
            // Without manually calling setNeedsLayout here it was observed that a call to
            // layoutIfNeeded() immediately after loading the view would not perform a layout, and
            // therefore would not update the preferredContentSize in viewDidLayoutSubviews().
            // UI-5797
            view.setNeedsLayout()
        }
    }

    // MARK: ViewEnvironmentObserving

    func apply(environment: ViewEnvironment) {
        viewEnvironmentHolder.viewEnvironment = environment
    }
}

#endif

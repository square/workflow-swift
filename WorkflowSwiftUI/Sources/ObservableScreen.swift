#if canImport(UIKit)

import SwiftUI
import Workflow
import WorkflowUI

/// A screen that renders SwiftUI views with an observable model for fine-grained invalidations.
///
/// Screens conforming to this protocol will render SwiftUI views that observe fine-grained changes
/// to the underlying model, and selectively invalidate in response to changes to properties that
/// are accessed by the view.
///
/// Invalidations happen when the observed state is mutated, during actions or the
/// `workflowDidChange` method. When this screen is rendered, a new model is injected into the
/// store. Any invalidated views will then be updated with the new model by SwiftUI during its own
/// rendering cycle.
///
/// To use this protocol with a workflow, your workflow should render a type that conforms to
/// ``ObservableModel``, and then map to a screen implementation that uses that concrete model
/// type. See ``ObservableModel`` for options on how to render one easily.
public protocol ObservableScreen: Screen {
    /// The type of the root view rendered by this screen.
    associatedtype Content: View
    /// The type of the model that this screen observes.
    associatedtype Model: ObservableModel

    /// The model that this screen observes.
    var model: Model { get }

    // MARK: - Optional configuration

    /// The sizing options for the screen.
    var sizingOptions: SwiftUIScreenSizingOptions { get }

    /// The preferred status bar style when this screen is in control of the status bar appearance.
    ///
    /// Defaults to `.default`.
    func preferredStatusBarStyle(in context: ObservableScreenContext) -> UIStatusBarStyle

    /// If the status bar is shown or hidden when this screen is in control of
    /// the status bar appearance.
    ///
    /// Defaults to `false`
    func prefersStatusBarHidden(in context: ObservableScreenContext) -> Bool

    /// The preferred animation style when the status bar appearance changes when this screen is in
    /// control of the status bar appearance.
    ///
    /// Defaults to `.fade`
    func preferredStatusBarUpdateAnimation(
        in context: ObservableScreenContext
    ) -> UIStatusBarAnimation

    /// The supported interface orientations of this screen.
    ///
    /// Defaults to all orientations for iPad, and portrait / portrait upside down for iPhone.
    func supportedInterfaceOrientations(
        in context: ObservableScreenContext
    ) -> UIInterfaceOrientationMask

    /// Which screen edges should defer system gestures when this screen is in control.
    ///
    /// Defaults to `[]` (none).
    func preferredScreenEdgesDeferringSystemGestures(
        in context: ObservableScreenContext
    ) -> UIRectEdge

    /// If the home indicator should be auto hidden or not when this screen is in control of the
    /// home indicator appearance.
    ///
    /// Defaults to `false`
    func prefersHomeIndicatorAutoHidden(in context: ObservableScreenContext) -> Bool

    /// Invoked when a physical button is pressed, such as one of a hardware keyboard. Return `true`
    /// if the event is handled by the screen, otherwise `false` to forward the message along the
    /// responder chain.
    ///
    /// Defaults to `false` for all events.
    func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) -> Bool

    /// This method is called when VoiceOver is enabled and the escape gesture is performed (a
    /// 2-finger Z shape).
    ///
    /// Implement this method if your screen is a modal that can be dismissed without an explicit
    /// action. For example, most modals with a close button should implement this method and have
    /// the same behavior as tapping close. Return `true` if this method did dismiss the modal.
    ///
    /// Defaults to `false`.
    func accessibilityPerformEscape() -> Bool

    /// Constructs the root view for this screen. This is only called once to initialize the view.
    /// After the initial construction, the view will be updated by injecting new values into the
    /// store.
    @ViewBuilder
    static func makeView(store: Store<Model>) -> Content
}

/// Context that holds view values for `ObservableScreen` customization hooks.
public struct ObservableScreenContext {
    /// The view environment of the associated view controller.
    public let environment: ViewEnvironment

    /// The safe area insets of this screen in its current position.
    public let safeAreaInsets: UIEdgeInsets

    /// The size of the view controller's containing window, if available.
    public let windowSize: CGSize?

    public init(
        environment: ViewEnvironment,
        safeAreaInsets: UIEdgeInsets,
        windowSize: CGSize? = nil
    ) {
        self.environment = environment
        self.safeAreaInsets = safeAreaInsets
        self.windowSize = windowSize
    }
}

extension ObservableScreen {
    public var sizingOptions: SwiftUIScreenSizingOptions {
        []
    }

    public func preferredStatusBarStyle(in context: ObservableScreenContext) -> UIStatusBarStyle {
        .default
    }

    public func prefersStatusBarHidden(in context: ObservableScreenContext) -> Bool {
        false
    }

    public func preferredStatusBarUpdateAnimation(
        in context: ObservableScreenContext
    ) -> UIStatusBarAnimation {
        .fade
    }

    public func supportedInterfaceOrientations(
        in context: ObservableScreenContext
    ) -> UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .pad {
            .all
        } else {
            [.portrait, .portraitUpsideDown]
        }
    }

    public func preferredScreenEdgesDeferringSystemGestures(
        in context: ObservableScreenContext
    ) -> UIRectEdge {
        []
    }

    public func prefersHomeIndicatorAutoHidden(in context: ObservableScreenContext) -> Bool {
        false
    }

    public func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) -> Bool {
        false
    }

    public func accessibilityPerformEscape() -> Bool {
        false
    }
}

extension ObservableScreen {
    public func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
        ViewControllerDescription(
            performInitialUpdate: false,
            type: ObservableScreenViewController<Self, Content>.self,
            environment: environment,
            build: {
                let (store, setModel) = Store.make(model: model)
                return ObservableScreenViewController(
                    setModel: setModel,
                    viewEnvironment: environment,
                    rootView: Self.makeView(store: store),
                    screen: self
                )
            },
            update: { hostingController in
                hostingController.update(screen: self)
                // ViewEnvironment updates are handled by the ModeledHostingController internally
            }
        )
    }
}

public struct SwiftUIScreenSizingOptions: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let preferredContentSize: SwiftUIScreenSizingOptions = .init(rawValue: 1 << 0)
}

private struct ViewEnvironmentModifier: ViewModifier {
    @ObservedObject var holder: ViewEnvironmentHolder

    func body(content: Content) -> some View {
        content
            .environment(\.viewEnvironment, holder.viewEnvironment)
    }
}

private final class ViewEnvironmentHolder: ObservableObject {
    @Published var viewEnvironment: ViewEnvironment

    init(viewEnvironment: ViewEnvironment) {
        self.viewEnvironment = viewEnvironment
    }
}

private final class ObservableScreenViewController<ScreenType: ObservableScreen, Content: View>:
    UIHostingController<ModifiedContent<Content, ViewEnvironmentModifier>>,
    ViewEnvironmentObserving
{
    typealias Model = ScreenType.Model

    private let setModel: (Model) -> Void
    private let viewEnvironmentHolder: ViewEnvironmentHolder

    private var screen: ScreenType
    private var hasLaidOutOnce = false
    private var maxFrameWidth: CGFloat = 0
    private var maxFrameHeight: CGFloat = 0

    private var previousPreferredStatusBarStyle: UIStatusBarStyle?
    private var previousPrefersStatusBarHidden: Bool?
    private var previousSupportedInterfaceOrientations: UIInterfaceOrientationMask?
    private var previousPreferredScreenEdgesDeferringSystemGestures: UIRectEdge?
    private var previousPrefersHomeIndicatorAutoHidden: Bool?

    init(
        setModel: @escaping (Model) -> Void,
        viewEnvironment: ViewEnvironment,
        rootView: Content,
        screen: ScreenType
    ) {
        self.setModel = setModel
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
        setModel(screen.model)
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

    private func makeCurrentContext() -> ObservableScreenContext {
        ObservableScreenContext(
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

    private func updateViewControllerContainmentForwarding() {
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

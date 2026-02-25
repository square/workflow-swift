#if canImport(UIKit)

import SwiftUI
import WorkflowUI

/// Context that holds view values for ``ObservableScreen`` and ``SelfContainedScreen``
/// customization hooks.
public struct HostingScreenContext {
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

/// Shared configuration requirements for ``ObservableScreen`` and ``SelfContainedScreen``.
///
/// > Important: Do not conform to this protocol directly. Use ``ObservableScreen`` or
/// > ``SelfContainedScreen`` instead.
public protocol _HostingScreen: Screen {
    /// The sizing options for the screen.
    var sizingOptions: SwiftUIScreenSizingOptions { get }

    /// The preferred status bar style when this screen is in control of the status bar appearance.
    ///
    /// Defaults to `.default`.
    func preferredStatusBarStyle(in context: HostingScreenContext) -> UIStatusBarStyle

    /// If the status bar is shown or hidden when this screen is in control of
    /// the status bar appearance.
    ///
    /// Defaults to `false`
    func prefersStatusBarHidden(in context: HostingScreenContext) -> Bool

    /// The preferred animation style when the status bar appearance changes when this screen is in
    /// control of the status bar appearance.
    ///
    /// Defaults to `.fade`
    func preferredStatusBarUpdateAnimation(
        in context: HostingScreenContext
    ) -> UIStatusBarAnimation

    /// The supported interface orientations of this screen.
    ///
    /// Defaults to all orientations for iPad, and portrait / portrait upside down for iPhone.
    func supportedInterfaceOrientations(
        in context: HostingScreenContext
    ) -> UIInterfaceOrientationMask

    /// Which screen edges should defer system gestures when this screen is in control.
    ///
    /// Defaults to `[]` (none).
    func preferredScreenEdgesDeferringSystemGestures(
        in context: HostingScreenContext
    ) -> UIRectEdge

    /// If the home indicator should be auto hidden or not when this screen is in control of the
    /// home indicator appearance.
    ///
    /// Defaults to `false`
    func prefersHomeIndicatorAutoHidden(in context: HostingScreenContext) -> Bool

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
}

extension _HostingScreen {
    public var sizingOptions: SwiftUIScreenSizingOptions {
        []
    }

    public func preferredStatusBarStyle(in context: HostingScreenContext) -> UIStatusBarStyle {
        .default
    }

    public func prefersStatusBarHidden(in context: HostingScreenContext) -> Bool {
        false
    }

    public func preferredStatusBarUpdateAnimation(
        in context: HostingScreenContext
    ) -> UIStatusBarAnimation {
        .fade
    }

    public func supportedInterfaceOrientations(
        in context: HostingScreenContext
    ) -> UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .pad {
            .all
        } else {
            [.portrait, .portraitUpsideDown]
        }
    }

    public func preferredScreenEdgesDeferringSystemGestures(
        in context: HostingScreenContext
    ) -> UIRectEdge {
        []
    }

    public func prefersHomeIndicatorAutoHidden(in context: HostingScreenContext) -> Bool {
        false
    }

    public func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) -> Bool {
        false
    }

    public func accessibilityPerformEscape() -> Bool {
        false
    }
}

#endif

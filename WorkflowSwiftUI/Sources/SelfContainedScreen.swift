#if canImport(UIKit)

import SwiftUI
import WorkflowUI

/// A screen that renders a self-contained SwiftUI view with no external observable model.
///
/// Use this protocol for SwiftUI screens that manage their own state internally (via `@State`,
/// `@StateObject`, etc.), or that display entirely static content. Unlike ``ObservableScreen``,
/// no model wiring is required — the view is constructed once via ``makeView()`` and drives
/// itself from that point on.
///
/// ```swift
/// struct LoadingScreen: SelfContainedScreen {
///     static func makeView() -> some View {
///         ProgressView()
///     }
/// }
/// ```
public protocol SelfContainedScreen: _HostingScreen {
    /// The type of the root view rendered by this screen.
    associatedtype Content: View

    /// Constructs the root view for this screen. This is only called once to initialize the view.
    /// After the initial construction, the view manages its own state internally.
    @ViewBuilder
    static func makeView() -> Content
}

extension SelfContainedScreen {
    public func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
        ViewControllerDescription(
            performInitialUpdate: false,
            type: SelfContainedScreenViewController<Self, Content>.self,
            environment: environment,
            build: {
                SelfContainedScreenViewController(
                    viewEnvironment: environment,
                    rootView: Self.makeView(),
                    screen: self
                )
            },
            update: { viewController in
                viewController.update(screen: self)
                // ViewEnvironment updates are handled by the hosting controller internally
            }
        )
    }
}

private final class SelfContainedScreenViewController<ScreenType: SelfContainedScreen, Content: View>:
    _HostingScreenViewController<ScreenType, Content>
{}

#endif

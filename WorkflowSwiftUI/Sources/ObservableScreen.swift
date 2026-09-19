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
public protocol ObservableScreen: _HostingScreen {
    /// The type of the root view rendered by this screen.
    associatedtype Content: View
    /// The type of the model that this screen observes.
    associatedtype Model: ObservableModel

    /// The model that this screen observes.
    var model: Model { get }

    /// Constructs the root view for this screen. This is only called once to initialize the view.
    /// After the initial construction, the view will be updated by injecting new values into the
    /// store.
    @ViewBuilder
    static func makeView(store: Store<Model>) -> Content
}

/// A compatibility alias for ``HostingScreenContext``.
public typealias ObservableScreenContext = HostingScreenContext

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

private final class ObservableScreenViewController<ScreenType: ObservableScreen, Content: View>:
    _HostingScreenViewController<ScreenType, Content>
{
    typealias Model = ScreenType.Model

    private let setModel: (Model) -> Void

    init(
        setModel: @escaping (Model) -> Void,
        viewEnvironment: ViewEnvironment,
        rootView: Content,
        screen: ScreenType
    ) {
        self.setModel = setModel
        super.init(viewEnvironment: viewEnvironment, rootView: rootView, screen: screen)
    }

    override func update(screen: ScreenType) {
        super.update(screen: screen)
        setModel(screen.model)
    }
}

#endif

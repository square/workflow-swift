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

    /// The sizing options for the screen.
    var sizingOptions: SwiftUIScreenSizingOptions { get }
    /// The model that this screen observes.
    var model: Model { get }

    /// Constructs the root view for this screen. This is only called once to initialize the view.
    /// After the initial construction, the view will be updated by injecting new values into the
    /// store.
    @ViewBuilder
    static func makeView(store: Store<Model>) -> Content
}

extension ObservableScreen {
    public var sizingOptions: SwiftUIScreenSizingOptions { [] }
}

extension ObservableScreen {
    public func viewControllerDescription(environment: ViewEnvironment) -> ViewControllerDescription {
        ViewControllerDescription(
            type: ModeledHostingController<Model, Content>.self,
            environment: environment,
            build: {
                let (store, setModel) = Store.make(model: model)
                return ModeledHostingController(
                    setModel: setModel,
                    viewEnvironment: environment,
                    rootView: Self.makeView(store: store),
                    sizingOptions: sizingOptions
                )
            },
            update: { hostingController in
                hostingController.setModel(model)
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

private final class ModeledHostingController<Model, Content: View>: UIHostingController<ModifiedContent<Content, ViewEnvironmentModifier>>, ViewEnvironmentObserving {
    let setModel: (Model) -> Void

    private let viewEnvironmentHolder: ViewEnvironmentHolder

    var swiftUIScreenSizingOptions: SwiftUIScreenSizingOptions {
        didSet {
            updateSizingOptionsIfNeeded()

            if !hasLaidOutOnce {
                setNeedsLayoutBeforeFirstLayoutIfNeeded()
            }
        }
    }

    private var hasLaidOutOnce = false

    init(
        setModel: @escaping (Model) -> Void,
        viewEnvironment: ViewEnvironment,
        rootView: Content,
        sizingOptions swiftUIScreenSizingOptions: SwiftUIScreenSizingOptions
    ) {
        self.setModel = setModel
        self.viewEnvironmentHolder = ViewEnvironmentHolder(viewEnvironment: viewEnvironment)
        self.swiftUIScreenSizingOptions = swiftUIScreenSizingOptions

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

    override func viewDidLoad() {
        super.viewDidLoad()

        // `UIHostingController`'s provides a system background color by default. In order to
        // support `ObervableModelScreen`s being composed in contexts where it is composed within another
        // view controller where a transparent background is more desirable, we set the background
        // to clear to allow this kind of flexibility.
        view.backgroundColor = .clear

        setNeedsLayoutBeforeFirstLayoutIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        defer { hasLaidOutOnce = true }

        if #available(iOS 16.0, *) {
            // Handled in initializer, but set it on first layout to resolve a bug where the PCS is
            // not updated appropriately after the first layout.
            // UI-5797
            if !hasLaidOutOnce,
               swiftUIScreenSizingOptions.contains(.preferredContentSize)
            {
                let size = view.sizeThatFits(view.frame.size)

                if preferredContentSize != size {
                    preferredContentSize = size
                }
            }
        } else if swiftUIScreenSizingOptions.contains(.preferredContentSize) {
            let size = view.sizeThatFits(view.frame.size)

            if preferredContentSize != size {
                preferredContentSize = size
            }
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        applyEnvironmentIfNeeded()
    }

    private func updateSizingOptionsIfNeeded() {
        if #available(iOS 16.0, *) {
            self.sizingOptions = swiftUIScreenSizingOptions.uiHostingControllerSizingOptions
        }

        if !swiftUIScreenSizingOptions.contains(.preferredContentSize),
           preferredContentSize != .zero
        {
            preferredContentSize = .zero
        }
    }

    private func setNeedsLayoutBeforeFirstLayoutIfNeeded() {
        if swiftUIScreenSizingOptions.contains(.preferredContentSize) {
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

extension SwiftUIScreenSizingOptions {
    @available(iOS 16.0, *)
    fileprivate var uiHostingControllerSizingOptions: UIHostingControllerSizingOptions {
        var options = UIHostingControllerSizingOptions()

        if contains(.preferredContentSize) {
            options.insert(.preferredContentSize)
        }

        return options
    }
}

#endif

#if canImport(UIKit)

import UIKit

/// Opts a container into forwarding content-level integrations to one designated child.
///
/// This is not the currently visible screen, a presentation target, or a request to search
/// the child hierarchy. Navigation containers must not forward to their selected entry.
/// A presentation wrapper can forward to its base, excluding its modals and toasts.
public protocol ScreenContentProviding: AnyObject {
    /// The stable lifecycle for the designated child, retained by this container.
    var screenContent: ScreenContentLifecycle { get }
}

/// Prepares a container's designated content and retires integrations when that content changes.
///
/// Create this alongside the initial child, without loading its view. Call `replace(with:)`
/// for replacements before containment or view loading (for example, from
/// `update(child:with:in:prepareReplacement:onChange:)`). Updating the same child is a no-op.
/// This lifecycle is independent of appearance: hiding a retained child does not replace it.
/// All access, including releasing observations, must occur on the main thread.
///
/// A wrapper creates one lifecycle with its initial child and keeps it across screen updates:
///
/// ```swift
/// // During initialization, before either controller's view loads:
/// screenContent = ScreenContentLifecycle(viewController: baseViewController)
///
/// // During screen updates, announce only replacement of the designated base:
/// update(
///     child: \.baseViewController,
///     with: screen.base,
///     in: environment,
///     prepareReplacement: { [screenContent] in screenContent.replace(with: $0) }
/// )
/// ```
public final class ScreenContentLifecycle {
    public private(set) var viewController: UIViewController

    private var observations: [WeakObservation] = []
    private var isReplacing = false

    public init(viewController: UIViewController) {
        self.viewController = viewController
    }

    /// Retires every old integration, then prepares the replacement synchronously.
    /// Preparation must not load the view or recursively replace this lifecycle's content.
    public func replace(with viewController: UIViewController) {
        guard self.viewController !== viewController else { return }
        precondition(!isReplacing, "Screen content cannot be replaced during preparation or retirement")
        isReplacing = true
        defer { isReplacing = false }

        observations.removeAll { $0.value == nil }
        let current = observations.compactMap(\.value)
        current.forEach { $0.retireContent() }
        self.viewController = viewController
        current.forEach { $0.prepareContent(viewController) }
    }

    /// Immediately prepares the current child, then prepares each replacement.
    ///
    /// Return a retirement closure for the prepared child. It runs before preparing a
    /// replacement, when the observation is removed/released, or when this lifecycle ends.
    /// Retain the observation for as long as the integration is needed. Neither observing
    /// nor replacing loads a view. A custom child may already have loaded its own view;
    /// integrations must check their own installation requirements.
    public func observe(
        prepare: @escaping (UIViewController) -> (() -> Void)
    ) -> Observation {
        precondition(!isReplacing, "Observers cannot be added during content replacement")
        isReplacing = true
        defer { isReplacing = false }
        observations.removeAll { $0.value == nil }
        let observation = Observation(prepare: prepare)
        observations.append(WeakObservation(value: observation))
        observation.prepareContent(viewController)
        return observation
    }

    deinit {
        observations.forEach { $0.value?.remove() }
    }

    /// A retained content integration. Removal is idempotent.
    public final class Observation {
        private var prepare: ((UIViewController) -> (() -> Void))?
        private var retire: (() -> Void)?

        fileprivate init(prepare: @escaping (UIViewController) -> (() -> Void)) {
            self.prepare = prepare
        }

        public func remove() {
            prepare = nil
            retireContent()
        }

        fileprivate func prepareContent(_ viewController: UIViewController) {
            retire = prepare?(viewController)
        }

        fileprivate func retireContent() {
            let retire = retire
            self.retire = nil
            retire?()
        }

        deinit {
            retire?()
        }
    }

    private struct WeakObservation {
        weak var value: Observation?
    }
}

#endif

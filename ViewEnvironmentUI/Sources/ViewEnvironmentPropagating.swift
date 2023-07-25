/*
 * Copyright 2023 Square Inc.
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

import Foundation
import ViewEnvironment

/// A node in a `ViewEnvironment` propagation tree.
///
/// This protocol describes the base functionality of every node in the tree:
/// - Reading the environment, via `environment`.
/// - Walking up the tree, via `environmentAncestor`.
/// - Walking down the tree, via `environmentDescendants`.
/// - Notifying a node that the environment changed, via `setNeedsEnvironmentUpdate()`.
/// - Override the ancestor and descendants
/// - Add environment update observations
/// - Flag the backing object for needing to have the `ViewEnvironment` reapplied (e.g. `setNeedsLayout()`)
///
/// This framework provides conformance of this protocol to `UIViewController` and `UIView`.
///
public protocol ViewEnvironmentPropagating: AnyObject {
    /// Calling this will flag this node for needing to update the `ViewEnvironment`. For `UIView`/`UIViewController`,
    /// this will occur on the next layout pass (`setNeedsLayout` will be called on the caller's behalf).
    ///
    /// Any `UIViewController`/`UIView` that conforms to `ViewEnvironmentObserving` _must_ call
    /// `applyEnvironmentIfNeeded()` in the subclass' `viewWillLayoutSubviews()` / `layoutSubviews()` respectively.
    ///
    /// - Important: Nodes providing manual conformance to this protocol should call `setNeedsEnvironmentUpdate()` on
    ///   all `environmentDescendants` (which is behind the `ViewEnvironmentWiring` SPI namespace).
    ///
    func setNeedsEnvironmentUpdate()

    /// The `ViewEnvironment` propagation ancestor.
    ///
    /// This describes the ancestor that the `ViewEnvironment` is inherited from.
    ///
    /// To override the return value of this property for `UIViewController`/`UIView` subclasses, set the
    /// `environmentAncestorOverride` property.  If no override is present, the return value will be `parent ??
    /// `presentingViewController`/`superview`.
    ///
    /// Ancestor-descendent bindings must be mutually agreed. If the value of the ancestor is `nil`, then by default,
    /// other nodes configured with this node as a descendant will not notify this node of needing an environment
    /// update as it changes. This allows a node to effectively act as a root node when needed (e.g. bridging from
    /// other propagation systems like WorkflowUI).
    ///
    @_spi(ViewEnvironmentWiring)
    var environmentAncestor: ViewEnvironmentPropagating? { get }

    /// The `ViewEnvironment` propagation descendants.
    ///
    /// This describes the descendants that will be notified when the `ViewEnvironment` changes.
    ///
    /// Ancestor-descendent bindings must be mutually agreed. If a descendant's `environmentAncestor` is not `self`,
    /// that descendant will not be notified when the `ViewEnvironment` changes.
    ///
    /// To override the return value of this property for `UIViewController`/`UIView` subclasses, set the
    /// `environmentDescendantsOverride` property.  If no override is present, the return value will be a collection
    /// of all `children` in  addition to the `presentedViewController` for `UIViewController`s and `subviews` for
    /// `UIView`s.
    ///
    @_spi(ViewEnvironmentWiring)
    var environmentDescendants: [ViewEnvironmentPropagating] { get }

    /// The default ancestor for `ViewEnvironment` propagation.
    ///
    @_spi(ViewEnvironmentWiring)
    var defaultEnvironmentAncestor: ViewEnvironmentPropagating? { get }

    /// The default descendants for `ViewEnvironment` propagation.
    ///
    @_spi(ViewEnvironmentWiring)
    var defaultEnvironmentDescendants: [ViewEnvironmentPropagating] { get }

    /// Informs the backing object that this specific node should be flagged for another application of the
    /// `ViewEnvironment`.
    ///
    /// For `UIViewController`/`UIView`s this typically corresponds to `setNeedsLayout()`.
    ///
    @_spi(ViewEnvironmentWiring)
    func setNeedsApplyEnvironment()
}

extension ViewEnvironmentPropagating {
    /// The `ViewEnvironment` that is flowing through the propagation hierarchy.
    ///
    /// If you'd like to provide overrides for the environment as it flows through a node, you should conform to
    /// `ViewEnvironmentObserving` and provide those overrides in `customize(environment:)`. E.g.:
    /// ```swift
    /// func customize(environment: inout ViewEnvironment) {
    ///     environment.traits.mode = .dark
    /// }
    /// ```
    ///
    /// By default, this property gets the environment by recursively walking to the root of the
    /// propagation path, and applying customizations on the way back down. The invalidation path may be
    /// interrupted if a node has set it's `environmentAncestor` to `nil`, even if there is a node
    /// which specifies this node as an `environmentDescendant`.
    ///
    /// If you'd like to update the return value of this variable and have those changes propagated through the
    /// propagation hierarchy, conform to `ViewEnvironmentObserving` and call `setNeedsEnvironmentUpdate()` and wait
    /// for the system to call `apply(context:)` when appropriate (e.g. on the next layout pass for
    /// `UIViewController`/`UIView` subclasses).
    ///
    /// - Important: `UIViewController` and `UIView` conformers _must_ call `applyEnvironmentIfNeeded()` in
    ///   `viewWillLayoutSubviews()` and `layoutSubviews()` respectively.
    ///
    public var environment: ViewEnvironment {
        var environment = environmentAncestor?.environment ?? .empty

        for storedCustomization in customizations {
            storedCustomization.customization(&environment)
        }

        if let observing = self as? ViewEnvironmentObserving {
            observing.customize(environment: &environment)
        }

        return environment
    }

    /// Consumers _must_ call this function when the environment should be re-applied, e.g. in
    /// `viewWillLayoutSubviews()` for `UIViewController`s and `layoutSubviews()` for `UIView`s.
    ///
    /// This will call `apply(environment:)` on the receiver if the node has been flagged for needing update.
    ///
    public func applyEnvironmentIfNeeded() {
        guard needsEnvironmentUpdate else { return }

        needsEnvironmentUpdate = false

        if let observing = self as? ViewEnvironmentObserving {
            let environment = observing.environment
            observing.apply(environment: environment)
        }
    }

    /// Notifies all appropriate descendants that the environment needs update.
    ///
    /// Ancestor-descendent bindings must be mutually agreed for this method to notify them. If a descendant's
    /// `environmentAncestor` is not `self` it will not be notified of needing update.
    ///
    @_spi(ViewEnvironmentWiring)
    public func setNeedsEnvironmentUpdateOnAppropriateDescendants() {
        for descendant in environmentDescendants {
            // If the descendant's `environmentAncestor` is not `self` it has opted out of environment updates from this
            // node. The node is is likely acting as a root for propagation bridging purposes (e.g. from a Workflow
            // ViewEnvironment update).
            // Avoid updating the descendant if this is the case.
            if descendant.environmentAncestor === self {
                descendant.setNeedsEnvironmentUpdate()
            }
        }
    }

    /// Adds a `ViewEnvironment` change observation.
    ///
    /// The observation will only be active for as long as the returned lifetime is retained or
    /// `cancel()` is called on it.
    ///
    @_spi(ViewEnvironmentWiring)
    public func addEnvironmentNeedsUpdateObserver(
        _ onNeedsUpdate: @escaping ViewEnvironmentUpdateObservation
    ) -> ViewEnvironmentUpdateObservationLifetime {
        let object = ViewEnvironmentUpdateObservationKey()
        needsUpdateObservers[object] = onNeedsUpdate
        return .init { [weak self] in
            self?.needsUpdateObservers[object] = nil
        }
    }

    /// Adds a `ViewEnvironment` customization to this node.
    ///
    /// These customizations will occur before the node's `customize(environment:)` in cases where
    /// this node conforms to `ViewEnvironmentObserving`, and will occur the order in which they
    /// were added.
    ///
    /// The customization will only be active for as long as the returned lifetime is retained or
    /// until `remove()` is called on it.
    ///
    @_spi(ViewEnvironmentWiring)
    public func addEnvironmentCustomization(
        _ customization: @escaping ViewEnvironmentCustomization
    ) -> ViewEnvironmentCustomizationLifetime {
        let storedCustomization = StoredViewEnvironmentCustomization(customization: customization)
        customizations.append(storedCustomization)
        return .init { [weak self] in
            guard let self,
                let index = self.customizations.firstIndex(where: { $0 === storedCustomization })
            else {
                return
            }
            self.customizations.remove(at: index)
        }
    }

    /// The `ViewEnvironment` propagation ancestor.
    ///
    /// This describes the ancestor that the `ViewEnvironment` is inherited from.
    ///
    /// To override the return value of this property, set the `environmentAncestorOverride`.
    /// If no override is present, the return value will be `defaultEnvironmentAncestor`.
    ///
    @_spi(ViewEnvironmentWiring)
    public var environmentAncestor: ViewEnvironmentPropagating? {
        environmentAncestorOverride?() ?? defaultEnvironmentAncestor
    }

    /// The `ViewEnvironment` propagation descendants.
    ///
    /// This describes the descendants that will be notified when the `ViewEnvironment` changes.
    ///
    /// If a descendant's `environmentAncestor` is not `self`, that descendant will not be notified when the
    /// `ViewEnvironment` changes.
    ///
    /// To override the return value of this property, set the `environmentDescendantsOverride`.
    /// If no override is present, the return value will be `defaultEnvironmentDescendants`.
    ///
    @_spi(ViewEnvironmentWiring)
    public var environmentDescendants: [ViewEnvironmentPropagating] {
        environmentDescendantsOverride?() ?? defaultEnvironmentDescendants
    }

    /// ## SeeAlso ##
    /// - `environmentAncestorOverride`
    ///
    @_spi(ViewEnvironmentWiring)
    public typealias EnvironmentAncestorProvider = () -> ViewEnvironmentPropagating?

    /// This property allows you to override the propagation path of the `ViewEnvironment` as it flows through the
    /// node hierarchy by overriding the return value of `environmentAncestor`.
    ///
    /// The result of this closure should typically be the propagation node that the `ViewEnvironment` is inherited
    /// from. If the value of the ancestor is nil, by default, other nodes configured with this node as a descendant
    /// will not notify this node of needing an environment update as it changes. This allows a node to effectively
    /// act as a root node when needed (e.g. bridging from other propagation systems like WorkflowUI).
    ///
    /// If this value is `nil` (the default), the resolved value for the ancestor will be `defaultEnvironmentAncestor`.
    ///
    /// ## Important ##
    ///  - You must not set overrides while overrides are already set—doing so will throw an assertion. This assertion
    ///    prevents accidentally clobbering an existing propagation path customization defined somewhere out of your
    ///    control (e.g. Modals customization).
    ///
    @_spi(ViewEnvironmentWiring)
    public var environmentAncestorOverride: EnvironmentAncestorProvider? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.ancestorOverride) as? EnvironmentAncestorProvider
        }
        set {
            assert(
                newValue == nil
                    || environmentAncestorOverride == nil,
                "Attempting to set environment ancestor override when one is already set."
            )
            objc_setAssociatedObject(self, &AssociatedKeys.ancestorOverride, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    /// ## SeeAlso ##
    /// - `environmentDescendantsOverride`
    ///
    @_spi(ViewEnvironmentWiring)
    public typealias EnvironmentDescendantsProvider = () -> [ViewEnvironmentPropagating]

    /// This property allows you to override the propagation path of the `ViewEnvironment` as it flows through the
    /// node hierarchy by overriding the return value of `environmentDescendants`.
    ///
    /// The result of closure var should be the node that should be informed that there has been an update with the
    /// `ViewEnvironment` updates.
    ///
    /// If this value is `nil` (the default), the `environmentDescendants` will be resolved to
    /// `defaultEnvironmentDescendants`.
    ///
    /// ## Important ##
    ///  - You must not set overrides while overrides are already set. Doing so will throw an
    ///    assertion.
    ///
    @_spi(ViewEnvironmentWiring)
    public var environmentDescendantsOverride: EnvironmentDescendantsProvider? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.descendantsOverride) as? EnvironmentDescendantsProvider
        }
        set {
            assert(
                newValue == nil
                    || environmentDescendantsOverride == nil,
                "Attempting to set environment descendants override when one is already set."
            )
            objc_setAssociatedObject(self, &AssociatedKeys.descendantsOverride, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }

    /// Returns an `Equatable` representation of the `ViewEnvironmentPropagating` environment
    /// ancestor tree path.
    ///
    /// This can be useful, for example, if you need to determine if any ancestor was inserted or
    /// removed above this node.
    ///
    /// The `Equatable` implementation of this type compares the tree as an array of weak
    /// references.
    ///
    @_spi(ViewEnvironmentWiring)
    public var environmentAncestorPath: EnvironmentAncestorPath {
        var path = EnvironmentAncestorPath()

        if let first = environmentAncestor {
            for node in sequence(first: first, next: \.environmentAncestor) {
                path.append(node)
            }
        }

        return path
    }

    @_spi(ViewEnvironmentWiring)
    public typealias EnvironmentAncestorPath = ViewEnvironmentPropagatingAncestorPath
}

/// An `Equatable` representation of the `ViewEnvironmentPropagating` environment ancestor tree
/// path.
///
/// This can be useful, for example, if you need to determine if any ancestor was inserted or
/// removed above this node.
///
/// The `Equatable` implementation of this type compares the tree as an array of weak references.
///
@_spi(ViewEnvironmentWiring)
public struct ViewEnvironmentPropagatingAncestorPath: Equatable {
    private var nodes: [WeakBox] = []

    fileprivate mutating func append(_ node: ViewEnvironmentPropagating) {
        nodes.append(WeakBox(node))
    }

    // Use a weak box to avoid retaining the node.
    //
    // We do this instead of `ObjectIdentifier` because `ObjectIdentifier`s are only valid for the
    // lifetime of the object being identified—the value of the pointer could be re-used if it is
    // deallocated.
    private struct WeakBox: Equatable {
        weak var node: ViewEnvironmentPropagating?

        init(_ node: ViewEnvironmentPropagating) {
            self.node = node
        }

        static func == (lhs: WeakBox, rhs: WeakBox) -> Bool {
            lhs.node === rhs.node
        }
    }
}

/// A closure that is called when the `ViewEnvironment` needs to be updated.
///
public typealias ViewEnvironmentUpdateObservation = (ViewEnvironment) -> Void

/// Describes the lifetime of a `ViewEnvironment` update observation.
///
/// The observation will be removed when `remove()` is called or the lifetime token is
/// de-initialized.
///
/// ## SeeAlso ##
/// - `addEnvironmentNeedsUpdateObserver(_:)`
///
public final class ViewEnvironmentUpdateObservationLifetime {
    /// Removes the observation.
    ///
    /// The observation is removed when the lifetime is de-initialized if this function was not
    /// called before then.
    ///
    public func remove() {
        guard let onRemove else {
            assertionFailure("Environment update observation was already removed")
            return
        }
        self.onRemove = nil
        onRemove()
    }

    private var onRemove: (() -> Void)?

    init(onRemove: @escaping () -> Void) {
        self.onRemove = onRemove
    }

    deinit {
        onRemove?()
    }
}

private enum ViewEnvironmentPropagatingNSObjectAssociatedKeys {
    static var needsEnvironmentUpdate = NSObject()
    static var needsUpdateObservers = NSObject()
    static var ancestorOverride = NSObject()
    static var descendantsOverride = NSObject()
    static var customizations = NSObject()
}

extension ViewEnvironmentPropagating {
    private typealias AssociatedKeys = ViewEnvironmentPropagatingNSObjectAssociatedKeys

    public func setNeedsEnvironmentUpdate() {
        needsEnvironmentUpdate = true

        if !needsUpdateObservers.isEmpty {
            let environment = environment

            for observer in needsUpdateObservers.values {
                observer(environment)
            }
        }

        if let observer = self as? ViewEnvironmentObserving {
            observer.environmentDidChange()

            setNeedsApplyEnvironment()
        }

        setNeedsEnvironmentUpdateOnAppropriateDescendants()
    }

    private var needsUpdateObservers: [ViewEnvironmentUpdateObservationKey: ViewEnvironmentUpdateObservation] {
        get {
            objc_getAssociatedObject(
                self,
                &AssociatedKeys.needsUpdateObservers
            ) as? [ViewEnvironmentUpdateObservationKey: ViewEnvironmentUpdateObservation] ?? [:]
        }
        set {
            objc_setAssociatedObject(
                self,
                &AssociatedKeys.needsUpdateObservers,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    var needsEnvironmentUpdate: Bool {
        get {
            let associatedObject = objc_getAssociatedObject(
                self,
                &AssociatedKeys.needsEnvironmentUpdate
            )
            return (associatedObject as? Bool) ?? true
        }
        set {
            objc_setAssociatedObject(
                self,
                &AssociatedKeys.needsEnvironmentUpdate,
                newValue,
                objc_AssociationPolicy.OBJC_ASSOCIATION_COPY
            )
        }
    }
}

private class ViewEnvironmentUpdateObservationKey: NSObject {}

/// A closure that customizes the `ViewEnvironment` as it flows through a propagation node.
///
public typealias ViewEnvironmentCustomization = (inout ViewEnvironment) -> Void

/// Describes the lifetime of a `ViewEnvironment` customization.
///
/// This customization will be removed when `remove()` is called or the lifetime token is
/// de-initialized.
///
/// ## SeeAlso ##
/// - `addEnvironmentCustomization(_:)`
///
public final class ViewEnvironmentCustomizationLifetime {
    /// Removes the observation.
    ///
    /// The customization is removed when the lifetime is de-initialized if this function was not
    /// called before then.
    ///
    public func remove() {
        guard let onRemove else {
            assertionFailure("Environment customization was already removed")
            return
        }
        self.onRemove = nil
        onRemove()
    }

    private var onRemove: (() -> Void)?

    init(onRemove: @escaping () -> Void) {
        self.onRemove = onRemove
    }

    deinit {
        onRemove?()
    }
}

extension ViewEnvironmentPropagating {
    fileprivate var customizations: [StoredViewEnvironmentCustomization] {
        get {
            objc_getAssociatedObject(
                self,
                &AssociatedKeys.customizations
            ) as? [StoredViewEnvironmentCustomization] ?? []
        }
        set {
            objc_setAssociatedObject(
                self,
                &AssociatedKeys.customizations,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

private final class StoredViewEnvironmentCustomization {
    var customization: ViewEnvironmentCustomization

    init(customization: @escaping ViewEnvironmentCustomization) {
        self.customization = customization
    }
}

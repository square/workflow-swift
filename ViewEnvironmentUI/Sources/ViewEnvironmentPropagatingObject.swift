/*
 * Copyright 2022 Square Inc.
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

import ViewEnvironment

/// A protocol describing a ``ViewEnvironmentPropagating`` object that can:
/// - Override the ancestor and descendants
/// - Add environment update observations
/// - Flag the backing object for needing to have the `ViewEnvironment` reapplied (e.g. `setNeedsLayout()`)
///
/// This protocol was abstracted to share propagation logic between `UIViewController` and `UIView`'s support for
/// ``ViewEnvironmentPropagating``, but could be used for any object-based node that wants to support
/// `ViewEnvironment` propagation.
///
public protocol ViewEnvironmentPropagatingObject: AnyObject, ViewEnvironmentPropagating {
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
    /// For `UIViewController`/`UIView`s this typically corresponds to `setNeedsUpdate()`.
    ///
    @_spi(ViewEnvironmentWiring)
    func setNeedsApplyEnvironment()
}

extension ViewEnvironmentObserving where Self: ViewEnvironmentPropagatingObject {
    public func applyEnvironmentIfNeeded() {
        guard needsEnvironmentUpdate else { return }

        needsEnvironmentUpdate = false

        apply(environment: viewEnvironment)
    }
}

extension ViewEnvironmentPropagatingObject {
    /// Adds a `ViewEnvironment` change observation.
    ///
    /// The observation will only be active for as long as the returned lifetime is retained or
    /// `cancel()` is called on it.
    ///
    /// - Tag: ViewEnvironmentPropagatingObject.addEnvironmentNeedsUpdateObserver
    ///
    @_spi(ViewEnvironmentWiring)
    public func addEnvironmentNeedsUpdateObserver(
        _ onNeedsUpdate: @escaping (ViewEnvironment) -> Void
    ) -> ViewEnvironmentUpdateObservationLifetime {
        let object = NSObject()
        needsUpdateObservers[object] = onNeedsUpdate
        return .init { [weak self] in
            self?.needsUpdateObservers[object] = nil
        }
    }

    /// The [`ViewEnvironment` propagation](x-source-tag://ViewEnvironmentObserving) ancestor.
    ///
    /// This describes the ancestor that the `ViewEnvironment` is inherited from.
    ///
    /// To override the return value of this property, set the ``environmentAncestorOverride``.
    /// If no override is present, the return value will be `defaultEnvironmentAncestor`.
    ///
    @_spi(ViewEnvironmentWiring)
    public var environmentAncestor: ViewEnvironmentPropagating? {
        environmentAncestorOverride?() ?? defaultEnvironmentAncestor
    }

    /// The [`ViewEnvironment` propagation](x-source-tag://ViewEnvironmentObserving)
    /// descendants.
    ///
    /// This describes the descendants that will be notified when the `ViewEnvironment` changes.
    ///
    /// To override the return value of this property, set the ``environmentDescendantsOverride``.
    /// If no override is present, the return value will be `defaultEnvironmentDescendants`.
    ///
    @_spi(ViewEnvironmentWiring)
    public var environmentDescendants: [ViewEnvironmentPropagating] {
        environmentDescendantsOverride?() ?? defaultEnvironmentDescendants
    }

    /// ## SeeAlso ##
    /// - [environmentAncestorOverride](x-source-tag://ViewEnvironmentObserving.environmentAncestorOverride)
    ///
    @_spi(ViewEnvironmentWiring)
    public typealias EnvironmentAncestorProvider = () -> ViewEnvironmentPropagating?

    /// This property allows you to override the propagation path of the `ViewEnvironment` as it flows through the
    /// node hierarchy by overriding the return value of `environmentAncestor`.
    ///
    /// The result of this closure should be the propagation node that the `ViewEnvironment` is inherited from.
    ///
    /// If this value is `nil` (the default), the resolved value for the ancestor will be `defaultEnvironmentAncestor`.
    ///
    /// ## Important ##
    ///  - You must not set overrides while overrides are already set—doing so will throw an assertion. This assertion
    ///    prevents accidentally clobbering an existing propagation path customization defined somewhere out of your
    ///    control (e.g. Modals customization).
    ///
    /// - Tag: ViewEnvironmentObserving.environmentAncestorOverride
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
    /// - ``environmentDescendantsOverride``
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
/// - [addEnvironmentNeedsUpdateObserver](x-source-tag://ViewEnvironmentPropagatingObject.addEnvironmentNeedsUpdateObserver)
///
public final class ViewEnvironmentUpdateObservationLifetime {
    /// Removes the observation.
    ///
    /// This is called in `deinit`.
    ///
    public func remove() {
        onRemove()
    }

    var onRemove: () -> Void

    init(onRemove: @escaping () -> Void) {
        self.onRemove = onRemove
    }

    deinit {
        remove()
    }
}

private enum ViewEnvironmentPropagatingNSObjectAssociatedKeys {
    static var needsEnvironmentUpdate = NSObject()
    static var needsUpdateObservers = NSObject()
    static var ancestorOverride = NSObject()
    static var descendantsOverride = NSObject()
}

extension ViewEnvironmentPropagatingObject {
    private typealias AssociatedKeys = ViewEnvironmentPropagatingNSObjectAssociatedKeys

    public func setNeedsEnvironmentUpdate() {
        needsEnvironmentUpdate = true

        if !needsUpdateObservers.isEmpty {
            let environment = viewEnvironment

            for observer in needsUpdateObservers.values {
                observer(environment)
            }
        }

        if self is ViewEnvironmentObserving {
            setNeedsApplyEnvironment()
        }

        environmentDescendants.forEach { $0.setNeedsEnvironmentUpdate() }
    }

    private var needsUpdateObservers: [NSObject: ViewEnvironmentUpdateObservation] {
        get {
            objc_getAssociatedObject(
                self,
                &AssociatedKeys.needsUpdateObservers
            ) as? [NSObject: ViewEnvironmentUpdateObservation] ?? [:]
        }
        set {
            objc_setAssociatedObject(
                self,
                &AssociatedKeys.needsUpdateObservers,
                newValue,
                .OBJC_ASSOCIATION_RETAIN
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

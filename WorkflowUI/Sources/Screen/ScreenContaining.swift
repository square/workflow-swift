#if canImport(UIKit)

import Foundation
import UIKit

/// Defines a type that semantically 'contains' a `Screen` instance.
///
/// The motivating use case for this protocol is to expose a means of unifying various types that provide
/// access to `Screen`s in a way that can be used without knowing their static type.
///
/// For example, without this protocol, we cannot identify that a `UIViewController` is an instance of
/// `ScreenViewController<S>` without specifying the associated screen's type.
///
/// ```swift
/// func makeUninspectableScreenVC() -> UIViewController {
///   struct LocalScreen: Screen { ... } // `LocalScreen` symbol is only visible in this function
///   return ScreenViewController(screen: LocalScreen(), environment: .empty)
/// }
///
/// let isSVC = makeUninspectableScreenVC() is ScreenViewController<???> // no generic can be specified here that makes this true
/// ```
///
/// Conceptually this API is intended to enable runtime traversal of a hierarchy of `SingleScreenContaining`
/// instances such that an 'inner' `Screen` value can be found at runtime. For example, if we had an instance
/// of `ScreenViewController<AnyScreen>` but only statically knew it was a `UIViewController`, we
/// can use the conformances to this protocol to conditionally cast & traverse the contained screens to find
/// the inner `wrappedScreen`.
public protocol SingleScreenContaining {
    /// The primary `Screen` the conforming type contains. Note that this may be ambiguous in some
    /// cases, for instance, if the conforming type logically contains multiple screens. Implementors should
    /// return the `Screen` which most appropriately reflects the 'primary' one for a given domain.
    var primaryScreen: any Screen { get }
}

extension SingleScreenContaining {
    /// Iteratively traverses a sequence of `primaryScreen` values until one is found that does _not_
    /// conform to `SingleScreenContaining`. Put another way, this returns the first `primaryScreen`
    /// that is a `Screen` and _not_ a `SingleScreenContaining` type.
    public func findInnermostPrimaryScreen() -> any Screen {
        var result = primaryScreen

        while let nextContainer = result as? SingleScreenContaining {
            result = nextContainer.primaryScreen
        }

        return result
    }
}

#endif

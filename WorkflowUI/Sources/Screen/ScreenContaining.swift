#if canImport(UIKit)

import Foundation
import UIKit

/// Defines a type that semantically 'contains' a `Screen`, but erases its associated static type information.
///
/// This enables referring to `any ScreenViewController` which is not possible without a protocol
/// like this because `ScreenViewController` is generic over its screen type and it's not possible to check
/// `viewController is ScreenViewController` without also specifying a specific screen type.
public protocol ScreenContaining {
    /// The underlying Screen the conforming type contains
    var containedScreen: any Screen { get }
}

extension ScreenContaining {
    /// Iteratively traverses a sequence of `containedScreen` values until one is found that does _not_
    /// conform to `ScreenContaining`. Put another way, this returns the first `containedScreen`
    /// that is a `Screen` and _not_ a `ScreenContaining` type.
    public func findInnermostScreen() -> any Screen {
        var result = containedScreen

        while let nextContainer = result as? ScreenContaining {
            result = nextContainer.containedScreen
        }

        return result
    }
}

#endif

#if canImport(UIKit)

import UIKit

extension UIViewController {
    /// Flags the view controller for needing a supported interface orientations update
    /// (`setNeedsUpdateOfSupportedInterfaceOrientations()`), and rotates to a supported interface orientation if the
    /// associated `view.window?.rootViewController?.supportedInterfaceOrientations` mask does not contain match the
    /// current `windowScene` orientation.
    public func setNeedsUpdateOfSupportedInterfaceOrientationsAndRotateIfNeeded() {
        // This approach is inspired by the solution found in the Flutter repository:
        // https://github.com/flutter/engine/blob/67440ccd58561a2b2f0336a3af695a07a6f9eff5/shell/platform/darwin/ios/framework/Source/FlutterViewController.mm#L1697-L1744

        // We need to indicate that this VC's supported orientations changed, even in cases where the current
        // orientation is supported, so that the system can utilize these new values to determine if a device
        // rotation should trigger a VC rotation.
        // If you do not call this function, the supported orientations are never re-queried.
        setNeedsUpdateOfSupportedInterfaceOrientations()

        guard
            let view = viewIfLoaded,
            let supportedInterfaceOrientations = view.window?.rootViewController?.supportedInterfaceOrientations,
            let scene = view.window?.windowScene,
            let sceneOrientationMask = UIInterfaceOrientationMask(scene.interfaceOrientation),
            sceneOrientationMask.isDisjoint(with: supportedInterfaceOrientations)
        else {
            return
        }

        let deviceOrientation = UIInterfaceOrientation(UIDevice.current.orientation)

        let orientations: [UIInterfaceOrientation] = [
            .portrait,
            .landscapeRight,
            .landscapeLeft,
            .portraitUpsideDown,
        ].sorted { lhs, _ in
            /// The current orientation should always be the first fallback.
            lhs == deviceOrientation
        }

        let newOrientation = orientations.first { orientation in
            UIInterfaceOrientationMask(orientation)?.isSubset(of: supportedInterfaceOrientations) == true
        }

        if newOrientation != nil {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: supportedInterfaceOrientations)) { error in
                print("Failed to request geometry update: \(error)")
            }
        }
    }
}

extension UIInterfaceOrientationMask {
    fileprivate init?(_ orientation: UIInterfaceOrientation) {
        switch orientation {
        case .portrait:
            self = .portrait

        case .portraitUpsideDown:
            self = .portraitUpsideDown

        case .landscapeLeft:
            self = .landscapeLeft

        case .landscapeRight:
            self = .landscapeRight

        case .unknown:
            return nil

        @unknown default:
            return nil
        }
    }
}

extension UIInterfaceOrientation {
    fileprivate init?(_ orientation: UIDeviceOrientation) {
        switch orientation {
        case .portrait:
            self = .portrait

        case .portraitUpsideDown:
            self = .portraitUpsideDown

        // The reason Left is mapped to Right and vice versa according to Apple's documentation on
        // `UIInterfaceOrientation`:
        // > Notice that UIDeviceOrientation.landscapeRight is assigned to UIInterfaceOrientation.landscapeLeft and
        // > UIDeviceOrientation.landscapeLeft is assigned to UIInterfaceOrientation.landscapeRight. The reason for this
        // > is that rotating the device requires rotating the content in the opposite direction.
        case .landscapeLeft:
            self = .landscapeRight

        case .landscapeRight:
            self = .landscapeLeft

        case .unknown,
             .faceUp,
             .faceDown:
            return nil

        @unknown default:
            return nil
        }
    }
}

#endif

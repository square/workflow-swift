#if DEBUG

import Foundation

/// Detection of the Xcode SwiftUI preview canvas.
///
/// Debug-only, because its sole consumer is `Store`'s debug-only suppression of Perception's
/// runtime check.
enum XcodePreviews {
    /// Whether this process is rendering SwiftUI previews.
    ///
    /// Xcode sets `XCODE_RUNNING_FOR_PREVIEWS` in the process that hosts the preview canvas and
    /// nowhere else, so this is `false` when the app runs on a simulator or a device.
    static let isRunning = isRunning(in: ProcessInfo.processInfo.environment)

    /// The environment lookup behind ``isRunning``.
    ///
    /// Separated so it can be exercised directly. ``isRunning`` reads the process environment
    /// once, which a test has no way to vary.
    static func isRunning(in environment: [String: String]) -> Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

#endif

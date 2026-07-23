#if canImport(UIKit)
#if DEBUG

import SwiftUI

extension SelfContainedScreen {
    /// Generates a static preview of this screen type.
    ///
    /// - Returns: A View for previews.
    public static func selfContainedScreenPreview() -> some View {
        makeView()
    }
}

// MARK: - Preview previews

private struct PreviewDemoSelfContainedScreen: SelfContainedScreen {
    static func makeView() -> some View {
        VStack {
            ProgressView()
            Text("Loading…")
        }
    }
}

struct PreviewDemoSelfContainedScreen_Preview: PreviewProvider {
    static var previews: some View {
        PreviewDemoSelfContainedScreen
            .selfContainedScreenPreview()
    }
}

#endif
#endif

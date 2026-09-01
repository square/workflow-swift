import Perception
@_spi(WorkflowRuntimeConfig) import Workflow

/// Runs `operation` with Perception's debug-only runtime check suppressed, if suppression applies.
///
/// Suppression is opt-in through
/// `Runtime.Configuration.suppressPerceptionCheckingWhenUsingObservation`, so `operation` executes
/// normally by default.
///
/// It is additionally applied whenever the process is rendering Xcode previews. That opt-in is
/// meant to be set once at app startup, and a preview has no equivalent entry point — the canvas
/// instantiates a view directly, with no app delegate and no runtime to configure — so a preview
/// would otherwise have no way to reach the configuration at all.
///
/// Two kinds of read need this. A ``Store`` read from a view body is the obvious one. The other is
/// a read a workflow makes of its own state during `render`, which never passes through a `Store`:
/// a preview host drives that render pass synchronously from a `UIViewControllerRepresentable`
/// callback, and *SwiftUI* is what calls that callback. Perception decides whether it is looking at
/// a SwiftUI view body by walking the call stack for AttributeGraph frames, so those frames are
/// present and the whole render pass is misreported. The same workflow in an app renders off a
/// runtime update instead, leaving no AttributeGraph frame on the stack, which is why these
/// warnings appear only in the canvas.
///
/// Known limitation below iOS 17 and its siblings: the availability check leaves suppression off
/// there, because a view body on those versions genuinely does need `WithPerceptionTracking` to
/// observe state at all — a warning about one is actionable, and hiding it would turn a preview
/// that silently stops updating into a preview that silently stops updating for no visible reason.
/// The cost is that a render-pass read still warns on those versions, where nothing can act on it,
/// since `WithPerceptionTracking` is a view modifier and a workflow's `render` cannot be wrapped in
/// one.
///
/// SPI rather than public API. It exists for preview hosts, of which there are few and all of them
/// library code, and it is meaningless to an app.
@_spi(PreviewHosting)
public func withPerceptionCheckSuppressed<T>(_ operation: () -> T) -> T {
    #if DEBUG && canImport(Observation)
    if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *),
       Runtime.configuration.suppressPerceptionCheckingWhenUsingObservation
       || XcodePreviews.isRunning
    {
        return _PerceptionLocals.$skipPerceptionChecking.withValue(true, operation: operation)
    }
    #endif
    return operation()
}

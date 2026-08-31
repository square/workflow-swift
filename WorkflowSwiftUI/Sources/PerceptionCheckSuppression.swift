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
func withPerceptionCheckSuppressed<T>(_ operation: () -> T) -> T {
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

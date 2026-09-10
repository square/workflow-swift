import Perception
@_spi(WorkflowRuntimeConfig) import Workflow

/// Runs `operation` with Perception's debug-only runtime check suppressed, unless the check has
/// been opted into.
///
/// The check is off by default — see `Runtime.Configuration.enablePerceptionChecking` — because at
/// iOS 17 and above it reports `Store` reads that native Observation is already tracking
/// correctly. Clients below iOS 17 opt in, where an untracked read is a real defect rather than a
/// false positive.
func withPerceptionCheckSuppressed<T>(_ operation: () -> T) -> T {
    #if DEBUG
    if !Runtime.configuration.enablePerceptionChecking {
        return _PerceptionLocals.$skipPerceptionChecking.withValue(true, operation: operation)
    }
    #endif
    return operation()
}

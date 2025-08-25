/// Tracks a completion flag during a test or during a portion of a larger test.
///
/// This can be useful during tests in which object deinitialization can have side-effects that you may
/// want to filter out when making assertions.
class CompletionTracker {
    private(set) var isComplete: Bool = false

    func complete() {
        isComplete = true
    }
}

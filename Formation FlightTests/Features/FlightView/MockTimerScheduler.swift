import Foundation
@testable import Formation_Flight

/// `TimerScheduling` is a MainActor protocol (B-28), so the mock is MainActor as well. Every
/// test suite that uses it is already `@MainActor`.
@MainActor
final class MockTimerScheduler: TimerScheduling {
    final class Token: AnyCancellableLike {
        var isCancelled = false
        func cancel() { isCancelled = true }
    }

    private var callback: (@MainActor () -> Void)?
    /// Token for the most recent `scheduleRepeating` call. A fresh token is issued per
    /// call so that one scheduler can be shared across several view models: cancelling
    /// (or deallocating) an earlier VM must not silence the timer for a later one.
    private var currentToken: Token?

    /// Number of times `scheduleRepeating` has been called.
    private(set) var scheduleCallCount = 0

    /// Whether the token from the most recent `scheduleRepeating` call has been cancelled.
    /// `false` if nothing has been scheduled yet.
    var isCancelled: Bool { currentToken?.isCancelled ?? false }

    func scheduleRepeating(interval: TimeInterval, onFire: @escaping @MainActor () -> Void) -> AnyCancellableLike {
        scheduleCallCount += 1
        let token = Token()
        self.currentToken = token
        self.callback = onFire
        return token
    }

    /// Invokes the most recently scheduled callback, unless its token was cancelled.
    func fire() {
        guard let currentToken, currentToken.isCancelled == false else { return }
        callback?()
    }
}

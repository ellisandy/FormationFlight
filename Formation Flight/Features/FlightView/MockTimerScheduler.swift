import Foundation
@testable import Formation_Flight

final class MockTimerScheduler: TimerScheduling {
    final class Token: AnyCancellableLike {
        var isCancelled = false
        func cancel() { isCancelled = true }
    }

    private var callback: (() -> Void)?
    private let token = Token()

    /// Number of times `scheduleRepeating` has been called.
    private(set) var scheduleCallCount = 0

    /// Whether the token handed out by `scheduleRepeating` has been cancelled.
    var isCancelled: Bool { token.isCancelled }

    func scheduleRepeating(interval: TimeInterval, onFire: @escaping () -> Void) -> AnyCancellableLike {
        scheduleCallCount += 1
        self.callback = onFire
        return token
    }

    func fire() {
        guard token.isCancelled == false else { return }
        callback?()
    }
}

import Foundation
@testable import Formation_Flight

final class MockTimerScheduler: TimerScheduling {
    final class Token: AnyCancellableLike {
        var isCancelled = false
        func cancel() { isCancelled = true }
    }

    private var callback: (() -> Void)?
    private let token = Token()

    func scheduleRepeating(interval: TimeInterval, onFire: @escaping () -> Void) -> AnyCancellableLike {
        self.callback = onFire
        return token
    }

    func fire() {
        guard token.isCancelled == false else { return }
        callback?()
    }
}

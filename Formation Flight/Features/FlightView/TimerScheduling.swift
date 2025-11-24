import Foundation

protocol AnyCancellableLike {
    func cancel()
}

protocol TimerScheduling {
    @discardableResult
    func scheduleRepeating(interval: TimeInterval, onFire: @escaping () -> Void) -> AnyCancellableLike
}

final class DefaultTimerScheduler: TimerScheduling {
    private final class Token: AnyCancellableLike {
        private var timer: Timer?
        init(timer: Timer) { self.timer = timer }
        func cancel() { timer?.invalidate(); timer = nil }
    }

    func scheduleRepeating(interval: TimeInterval, onFire: @escaping () -> Void) -> AnyCancellableLike {
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            onFire()
        }
        return Token(timer: timer)
    }
}

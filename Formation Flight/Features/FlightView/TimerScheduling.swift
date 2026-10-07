import Foundation

/// Deliberately nonisolated: `FlightViewModel.deinit` (which is nonisolated under Swift 6)
/// calls `cancel()` as a safety net, so the token must be usable off the MainActor.
protocol AnyCancellableLike {
    func cancel()
}

/// Schedules the view model's 1 Hz timing refresh. The protocol is MainActor-isolated because
/// its only consumer (`FlightViewModel`) is, and `onFire` mutates MainActor UI state (B-28).
@MainActor
protocol TimerScheduling {
    @discardableResult
    func scheduleRepeating(interval: TimeInterval, onFire: @escaping @MainActor () -> Void) -> AnyCancellableLike
}

@MainActor
final class DefaultTimerScheduler: TimerScheduling {
    private final class Token: AnyCancellableLike {
        private var timer: Timer?
        init(timer: Timer) { self.timer = timer }
        func cancel() { timer?.invalidate(); timer = nil }
    }

    func scheduleRepeating(interval: TimeInterval, onFire: @escaping @MainActor () -> Void) -> AnyCancellableLike {
        // B-17: `Timer.scheduledTimer` adds the timer in `.default` mode only, which the main run
        // loop leaves while tracking a scroll gesture, so the clock froze whenever the user
        // scrolled. Build the timer unscheduled and add it in `.common` mode instead.
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            // The timer lives on the main run loop, so its block always runs on the main
            // thread; `assumeIsolated` lets the MainActor callback run without a hop.
            MainActor.assumeIsolated { onFire() }
        }
        RunLoop.main.add(timer, forMode: .common)
        return Token(timer: timer)
    }
}

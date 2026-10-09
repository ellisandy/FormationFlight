import Foundation
import Testing
@testable import Formation_Flight

@MainActor
private final class MockCalloutSpeaker: CalloutSpeaking {
    private(set) var spoken: [String] = []
    private(set) var stopCallCount = 0
    func speak(_ text: String) { spoken.append(text) }
    func stop() { stopCallCount += 1 }
}

/// F-01 wiring between `FlightViewModel`, the banner, and the speaker. The rules themselves
/// are covered by `CalloutEngineTests`.
@Suite("FlightViewModel callouts")
@MainActor
struct FlightViewModelCalloutTests {
    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func makeVM(voice: Bool, speaker: MockCalloutSpeaker, timer: MockTimerScheduler,
                        clock: MutableClock) -> FlightViewModel {
        var settings = Settings.empty()
        settings.callouts.voiceEnabled = voice
        let vm = FlightViewModel(missionName: "TEST",
                                 missionType: .tot,
                                 missionDate: Self.start.addingTimeInterval(61),
                                 settings: settings,
                                 locationProvider: MockLocationProvider(),
                                 timerScheduler: timer,
                                 speaker: speaker,
                                 now: { clock.now })
        vm.start()
        return vm
    }

    @Test("A callout shows the banner, is spoken with voice on, and the banner clears")
    func bannerAndVoice() {
        let clock = MutableClock(Self.start)
        let timer = MockTimerScheduler()
        let speaker = MockCalloutSpeaker()
        let vm = makeVM(voice: true, speaker: speaker, timer: timer, clock: clock)

        timer.fire()
        #expect(vm.activeCallout == nil)
        clock.advance(by: 1)
        timer.fire()
        #expect(vm.activeCallout?.text == "One minute.")
        #expect(speaker.spoken == ["One minute."])

        clock.advance(by: FlightViewModel.calloutBannerDuration)
        timer.fire()
        #expect(vm.activeCallout == nil)
    }

    @Test("With voice off the banner still shows but nothing is spoken")
    func voiceOff() {
        let clock = MutableClock(Self.start)
        let timer = MockTimerScheduler()
        let speaker = MockCalloutSpeaker()
        let vm = makeVM(voice: false, speaker: speaker, timer: timer, clock: clock)

        timer.fire()
        clock.advance(by: 1)
        timer.fire()
        #expect(vm.activeCallout?.text == "One minute.")
        #expect(speaker.spoken.isEmpty)
    }

    @Test("stop() silences the speaker")
    func stopSilences() {
        let speaker = MockCalloutSpeaker()
        let vm = makeVM(voice: true, speaker: speaker, timer: MockTimerScheduler(), clock: MutableClock(Self.start))
        vm.stop()
        #expect(speaker.stopCallCount == 1)
    }
}

//
//  CalloutSpeaker.swift
//  Formation Flight
//
//  F-01: speaks callouts over whatever else is playing.
//

import AVFoundation

/// Speaks callout text. A protocol so the view model can be tested without audio.
@MainActor
protocol CalloutSpeaking: AnyObject {
    func speak(_ text: String)
    func stop()
}

/// `AVSpeechSynthesizer`-backed speaker.
///
/// Audio policy (product decision): other audio, such as an EFB app or music in the headset,
/// is ducked while a callout plays and restored afterwards, and callouts play even with the
/// ring/silent switch on (`.playback`). A new callout cuts off one still being spoken: the
/// latest is always the most relevant, and the engine already keeps them seconds apart.
@MainActor
final class SystemCalloutSpeaker: NSObject, CalloutSpeaking {
    private let synthesizer = AVSpeechSynthesizer()
    /// Utterances started but not yet finished or cancelled. The session is released (so the
    /// ducked audio comes back up) only once this returns to zero; a cut-off utterance's
    /// cancel callback must not end the ducking for the one that replaced it.
    private var outstanding = 0
    private var isSessionConfigured = false
    private var isSessionActive = false
    private var activationInProgress = false
    private var pendingText: String?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        pendingText = text
        if isSessionActive {
            speakPendingText()
        } else {
            activateSession()
        }
    }

    func stop() {
        pendingText = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func activateSession() {
        guard !activationInProgress else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            if !isSessionConfigured {
                try session.setCategory(.playback, mode: .voicePrompt,
                                        options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
                isSessionConfigured = true
            }
        } catch {
            AppLogger.flight.error("Callout audio session configuration failed: \(error.localizedDescription)")
            pendingText = nil
            return
        }

        activationInProgress = true
        if #available(iOS 27.0, *) {
            session.activate { [weak self] success, error in
                Task { @MainActor [weak self] in
                    self?.activationCompleted(success: success, error: error)
                }
            }
        } else {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                do {
                    try AVAudioSession.sharedInstance().setActive(true)
                    Task { @MainActor [weak self] in
                        self?.activationCompleted(success: true, error: nil)
                    }
                } catch {
                    Task { @MainActor [weak self] in
                        self?.activationCompleted(success: false, error: error)
                    }
                }
            }
        }
    }

    private func activationCompleted(success: Bool, error: Error?) {
        activationInProgress = false
        isSessionActive = success
        if let error {
            AppLogger.flight.error("Callout audio session activation failed: \(error.localizedDescription)")
            pendingText = nil
        } else {
            speakPendingText()
        }
    }

    private func speakPendingText() {
        guard let text = pendingText else { return }
        pendingText = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        // A little quicker than the default so "Five." … "One." each fit inside a second.
        utterance.rate = min(AVSpeechUtteranceMaximumSpeechRate, AVSpeechUtteranceDefaultSpeechRate * 1.1)
        outstanding += 1
        synthesizer.speak(utterance)
    }

    fileprivate func utteranceEnded() {
        outstanding = max(0, outstanding - 1)
        guard outstanding == 0, isSessionActive else { return }
        if #available(iOS 27.0, *) {
            AVAudioSession.sharedInstance().deactivate(options: .notifyOthersOnDeactivation) { [weak self] success, error in
                Task { @MainActor [weak self] in
                    self?.deactivationCompleted(success: success, error: error)
                }
            }
        } else {
            DispatchQueue.global(qos: .utility).async { [weak self] in
                do {
                    try AVAudioSession.sharedInstance().setActive(
                        false,
                        options: .notifyOthersOnDeactivation
                    )
                    Task { @MainActor [weak self] in
                        self?.deactivationCompleted(success: true, error: nil)
                    }
                } catch {
                    Task { @MainActor [weak self] in
                        self?.deactivationCompleted(success: false, error: error)
                    }
                }
            }
        }
    }

    private func deactivationCompleted(success: Bool, error: Error?) {
        isSessionActive = !success
        if let error {
            AppLogger.flight.error("Callout audio session deactivation failed: \(error.localizedDescription)")
        }
        if pendingText != nil {
            activateSession()
        }
    }
}

extension SystemCalloutSpeaker: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.utteranceEnded() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.utteranceEnded() }
    }
}

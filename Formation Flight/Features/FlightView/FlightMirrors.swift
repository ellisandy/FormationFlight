//
//  FlightMirrors.swift
//  Formation Flight
//
//  The mirrors a real flight screen feeds. Previews and tests build `FlightViewModel` without
//  them (or with fakes), so they never start a Live Activity.
//

import Foundation

enum FlightMirrors {
    /// The production mirrors (F-02): the Live Activity and the Apple Watch companion.
    ///
    /// Empty under UI tests and App Store screenshot runs (`-uiTestsResetStore`,
    /// `-uiTestsSeedFlights`): a Live Activity would put a Dynamic Island in the screenshots
    /// and outlive a test run that is killed rather than ended, and a paired simulator watch
    /// would be sent a flight no one is watching.
    @MainActor
    static func makeDefault(arguments: [String] = ProcessInfo.processInfo.arguments) -> [any FlightMirroring] {
        if isUITestOrScreenshotRun(arguments: arguments) { return [] }
        return [LiveActivityMirror(), WatchMirror()]
    }

    static func isUITestOrScreenshotRun(arguments: [String]) -> Bool {
        arguments.contains("-uiTestsResetStore") || arguments.contains("-uiTestsSeedFlights")
    }
}

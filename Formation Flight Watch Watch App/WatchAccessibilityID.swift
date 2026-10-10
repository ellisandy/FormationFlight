//
//  WatchAccessibilityID.swift
//  Formation Flight Watch Watch App
//
//  F-02: accessibility identifiers for the watch UI tests. Identifiers are for automation only;
//  every element also has a VoiceOver label. The UI test target keeps its own copy of these
//  strings (`WatchID` in the UI tests), since it cannot import the app.
//

enum WatchAccessibilityID {
    // Screens, one per phase.
    static let idleScreen = "watch.screen.idle"
    static let endedScreen = "watch.screen.ended"
    static let awaitingHackScreen = "watch.screen.awaitingHack"
    static let activeScreen = "watch.screen.active"
    static let staleScreen = "watch.screen.stale"

    static let idleMessage = "watch.idle.message"
    static let endedMessage = "watch.ended.message"
    static let awaitingHackTitle = "watch.awaitingHack.title"
    static let awaitingHackMessage = "watch.awaitingHack.message"
    static let hackTime = "watch.hackTime"

    static let banner = "watch.banner"
    static let countdown = "watch.countdown"
    /// Δ; its label says early / late / on time in words.
    static let delta = "watch.delta"
    /// ETE; its value carries the turn caption ("16:40, TURN 0:45 L").
    static let ete = "watch.ete"
    static let requiredGroundSpeed = "watch.reqGS"
    static let groundSpeed = "watch.gs"

    static let staleBadge = "watch.stale.badge"
    static let staleInstruction = "watch.stale.instruction"
    static let staleAge = "watch.stale.age"
}

//
//  InFlightInfo.swift
//  Formation Flight
//
//  Created by Jack Ellis on 11/14/25.
//


public enum InFlightInfo: String, CaseIterable {
    case tot = "ToT"
    case totDrift = "Drift"
    case distance =  "Dist"
    case bearing = "Final Bearing"
    case track = "Track"
    case currentGroundSpeed = "Cur GS"
    case requiredGroundSpeed = "Req GS"
    case expectedWindsDirection = "Wind Direction"
    case expectedWindsVelocity = "Wind Speed"
}

public enum InfoStatus {
    case good
    case bad
    case reallyBad
    case nutrual
}

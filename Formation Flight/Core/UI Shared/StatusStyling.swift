//
//  StatusStyling.swift
//  Formation Flight
//
//  UI styling for FlightViewModel.Status
//

import SwiftUI

extension FlightViewModel.Status {
    var color: Color {
        switch self {
        case .good:
            return .green
        case .bad:
            return .orange
        case .reallyBad:
            return .red
        case .unknown:
            return .secondary
        }
    }
}

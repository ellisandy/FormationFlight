//
//  StatusStyling.swift
//  Formation Flight
//
//  UI styling for FlightViewModel.Status
//

import SwiftUI

extension FlightViewModel.Status {
    /// Asset colours with darker light-appearance variants (D-01): the system green and orange
    /// are about 2.2:1 against a light background, under the 3:1 a status cue needs.
    var color: Color {
        switch self {
        case .good:
            return Color(.statusGood)
        case .bad:
            return Color(.statusWarning)
        case .reallyBad:
            return Color(.statusBad)
        case .unknown:
            return .secondary
        }
    }

    /// A shape cue alongside the tint (D-01) so status does not rely on colour alone.
    var symbolName: String? {
        switch self {
        case .good:
            return "checkmark.circle.fill"
        case .bad:
            return "exclamationmark.triangle.fill"
        case .reallyBad:
            return "xmark.octagon.fill"
        case .unknown:
            return nil
        }
    }

    /// Spoken equivalent of `symbolName`.
    var accessibilityDescription: String? {
        switch self {
        case .good:
            return String(localized: "Within tolerance", comment: "Flight status: delta within the yellow tolerance")
        case .bad:
            return String(localized: "Outside tolerance", comment: "Flight status: delta beyond yellow, within red tolerance")
        case .reallyBad:
            return String(localized: "Far outside tolerance", comment: "Flight status: delta beyond the red tolerance")
        case .unknown:
            return nil
        }
    }
}

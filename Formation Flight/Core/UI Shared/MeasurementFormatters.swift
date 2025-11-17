import Foundation

enum MeasurementFormatters {
    static func speedString(_ measurement: Measurement<UnitSpeed>?, unitPreference: Settings.SpeedUnit) -> String {
        guard let m = measurement else { return "--" }
        let unit: UnitSpeed
        switch unitPreference {
        case .kts:
            unit = .knots
        case .mph:
            unit = .milesPerHour
        case .kph:
            unit = .kilometersPerHour
        }
        let converted = m.converted(to: unit)
        let formatter = MeasurementFormatter()
        formatter.numberFormatter.maximumFractionDigits = 0
        formatter.numberFormatter.minimumFractionDigits = 0
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .short
        return formatter.string(from: converted)
    }
    
    static func distanceString(_ measurement: Measurement<UnitLength>?, unitPreference: Settings.DistanceUnit) -> String {
        guard let m = measurement else { return "--" }
        let unit: UnitLength
        switch unitPreference {
        case .nm:
            unit = .nauticalMiles
        case .mi:
            unit = .miles
        case .km:
            unit = .kilometers
        }
        let converted = m.converted(to: unit)
        let formatter = MeasurementFormatter()
        formatter.numberFormatter.maximumFractionDigits = 0
        formatter.numberFormatter.minimumFractionDigits = 0
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .short
        return formatter.string(from: converted)
    }
}

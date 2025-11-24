import Testing
import Foundation
import CoreLocation
@testable import Formation_Flight

@Suite("FormattingTests")
final class FormattingTests {
    
    @Test
    func test_timeHHmmss() {
        let calendar = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.calendar = calendar
        comps.year = 2023
        comps.month = 1
        comps.day = 1
        comps.hour = 13
        comps.minute = 37
        comps.second = 42
        guard let date = comps.date else {
            fatalError("Failed to create date from components")
        }
        
        #expect(Formatting.timeHHmmss(date) == "13:37:42")
        #expect(Formatting.timeHHmmss(nil) == "--:--:--")
    }
    
    @Test
    func test_durationHMS() {
        #expect(Formatting.durationHMS(0) == "00:00:00")
        #expect(Formatting.durationHMS(59.5) == "00:00:59")
        #expect(Formatting.durationHMS(61.2) == "00:01:01")
        #expect(Formatting.durationHMS(nil) == "--:--:--")
    }
    
    @Test
    func test_angle() {
        #expect(Formatting.angle(degrees: 12.6) == "13°")
        #expect(Formatting.angle(degrees: -12.4) == "--")
        #expect(Formatting.angle(nil) == "--")
        #expect(Formatting.angle(degrees: -1) == "--")
    }
    
    @Test
    func test_dms() {
        let coord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let (latStr, lonStr) = Formatting.dms(from: coord)
        #expect(latStr == "N 37 46.49")
        #expect(lonStr == "W 122 25.16")
        
        let nilCoord: CLLocationCoordinate2D? = nil
        let (nilLat, nilLon) = Formatting.dms(from: nilCoord)
        #expect(nilLat == "")
        #expect(nilLon == "")
    }
}

import Foundation
import Testing
@testable import Formation_Flight

/// B-15: the map picker's latitude/longitude fields are parsed on submit through
/// `CoordinateParsing.parse`, which must accept what people actually type: a decimal point,
/// a decimal comma, and stray whitespace, while rejecting junk and out-of-range values.
@Suite("CoordinateParsing")
struct CoordinateParsingTests {
    private let latitudeRange: ClosedRange<Double> = -90...90
    private let longitudeRange: ClosedRange<Double> = -180...180

    @Test("decimal point parses")
    func decimalPoint() {
        #expect(CoordinateParsing.parse("37.5", range: latitudeRange) == 37.5)
    }

    @Test("decimal comma parses as the same value")
    func decimalComma() {
        #expect(CoordinateParsing.parse("37,5", range: latitudeRange) == 37.5)
    }

    @Test("surrounding whitespace and a leading minus are accepted")
    func whitespaceAndSign() {
        #expect(CoordinateParsing.parse(" -122.1 ", range: longitudeRange) == -122.1)
    }

    @Test("an integer parses")
    func integer() {
        #expect(CoordinateParsing.parse("45", range: latitudeRange) == 45)
    }

    @Test("non-numeric text is rejected")
    func junk() {
        #expect(CoordinateParsing.parse("abc", range: latitudeRange) == nil)
        #expect(CoordinateParsing.parse("", range: latitudeRange) == nil)
        #expect(CoordinateParsing.parse("   ", range: latitudeRange) == nil)
        #expect(CoordinateParsing.parse("12.3.4", range: latitudeRange) == nil)
    }

    @Test("values outside the range are rejected, the bounds themselves are accepted")
    func outOfRange() {
        #expect(CoordinateParsing.parse("90.0001", range: latitudeRange) == nil)
        #expect(CoordinateParsing.parse("-91", range: latitudeRange) == nil)
        #expect(CoordinateParsing.parse("180.5", range: longitudeRange) == nil)
        #expect(CoordinateParsing.parse("90", range: latitudeRange) == 90)
        #expect(CoordinateParsing.parse("-180", range: longitudeRange) == -180)
    }

    @Test("non-finite spellings are rejected")
    func nonFinite() {
        #expect(CoordinateParsing.parse("nan", range: latitudeRange) == nil)
        #expect(CoordinateParsing.parse("inf", range: longitudeRange) == nil)
        #expect(CoordinateParsing.parse("-infinity", range: longitudeRange) == nil)
    }
}

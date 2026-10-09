import Foundation
import Testing
@testable import FormationFlightCore

@Suite("Double+Extensions Tests")
struct DoubleExtensionsTests {
    // Tolerance for floating point comparisons
    let tolerance = 1e-12

    func assertAlmostEqual(_ a: Double, _ b: Double) {
        #expect(abs(a - b) < tolerance)
    }

    @Test("Convert standard angles to radians")
    func testStandardAngles() {
        assertAlmostEqual(0.0.degreesToRadians, 0.0)
        assertAlmostEqual(90.0.degreesToRadians, .pi / 2)
        assertAlmostEqual(180.0.degreesToRadians, .pi)
        assertAlmostEqual(270.0.degreesToRadians, 3 * .pi / 2)
        assertAlmostEqual(360.0.degreesToRadians, 2 * .pi)
    }

    @Test("Convert negative angles to radians")
    func testNegativeAngles() {
        assertAlmostEqual((-45.0).degreesToRadians, -(.pi / 4))
        assertAlmostEqual((-90.0).degreesToRadians, -(.pi / 2))
    }

    @Test("Convert random angle to radians using formula")
    func testRandomAngle() {
        let angle = 123.456
        let expected = angle * .pi / 180.0
        assertAlmostEqual(angle.degreesToRadians, expected)
    }

    // MARK: - radiansToDegrees (B-36)

    @Test("Convert standard angles from radians to degrees")
    func testRadiansToDegreesStandardAngles() {
        assertAlmostEqual(0.0.radiansToDegrees, 0.0)
        assertAlmostEqual(Double.pi.radiansToDegrees, 180.0)
        assertAlmostEqual((Double.pi / 2).radiansToDegrees, 90.0)
        assertAlmostEqual((3 * Double.pi / 2).radiansToDegrees, 270.0)
        assertAlmostEqual((2 * Double.pi).radiansToDegrees, 360.0)
    }

    @Test("Convert negative radians to degrees")
    func testRadiansToDegreesNegativeAngles() {
        assertAlmostEqual((-(Double.pi / 4)).radiansToDegrees, -45.0)
        assertAlmostEqual((-(Double.pi / 2)).radiansToDegrees, -90.0)
    }

    @Test("degreesToRadians and radiansToDegrees round-trip", arguments: [0.0, 33.3, 90.0, 123.456, 270.0, 359.999, -17.5])
    func testDegreesRadiansRoundTrip(degrees: Double) {
        assertAlmostEqual(degrees.degreesToRadians.radiansToDegrees, degrees)
    }
}
